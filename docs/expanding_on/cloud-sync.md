# Cloud Sync & Disaster Recovery — Deep Dive

The cloud sync system provides end-to-end encrypted backup and multi-device continuity. All data is encrypted locally before upload — the server never sees plaintext. Recovery from device loss requires only signing in with email and password.

---

## Summary

User data syncs to cloud object storage encrypted with a device key derived from the user's master key (held server-side in an HSM). The system supports incremental sync, conflict resolution per file type, partial sync recovery, and device revocation. The UX goal: the user never thinks about backup. It just works.

---

## HKDF Key Derivation Details

### Key Hierarchy

```
Master Key (server-side HSM, never leaves server)
    │
    ├── HKDF-Expand(master, "device:" + device_id) → Device Key (32 bytes)
    │       │
    │       ├── HKDF-Expand(device_key, file_path) → Per-File Key (32 bytes)
    │       │       │
    │       │       └── AES-256-GCM(per_file_key, random_nonce, plaintext) → Ciphertext
    │       │
    │       └── HKDF-Expand(device_key, "manifest") → Manifest Key (32 bytes)
    │
    └── HKDF-Expand(master, "device:" + device_id_2) → Device Key 2
            └── (Same derivation, same results — all devices can decrypt all data)
```

### Why HKDF (Not PBKDF2 or Argon2)

- HKDF is for key derivation from already-strong key material (the master key)
- PBKDF2/Argon2 are for password-based derivation (slow by design)
- The master key is generated with full entropy — no need for password stretching
- HKDF is fast (single HMAC operation), enabling per-file key derivation without latency

### Per-File Key Derivation

```
fn derive_file_key(device_key: &[u8; 32], file_path: &str) -> [u8; 32] {
    let hkdf = Hkdf::<Sha256>::new(None, device_key);
    let mut file_key = [0u8; 32];
    // info = file path (ensures unique key per file)
    hkdf.expand(file_path.as_bytes(), &mut file_key)
        .expect("32 bytes is valid HKDF output length");
    file_key
}
```

### Key Properties

| Property | Guarantee |
|----------|-----------|
| Uniqueness | Each file gets a unique key (different path = different key) |
| Determinism | Same device key + same path = same file key (enables re-encryption) |
| Independence | Compromising one file key doesn't reveal others (HKDF output independence) |
| Forward secrecy | Per-file keys can't derive the device key (one-way function) |
| Cross-device | All devices derive the same file keys (same master → same device keys → same file keys) |

### Nonce Generation

Each encryption operation uses a random 12-byte nonce:

```
fn generate_nonce() -> [u8; 12] {
    let mut nonce = [0u8; 12];
    getrandom::getrandom(&mut nonce).expect("RNG failure");
    nonce
}
```

Nonces are prepended to ciphertext (not stored separately). Since nonces are random and files are re-encrypted on each sync, nonce reuse probability is negligible (birthday bound: 2^48 encryptions before concern).

---

## Conflict Resolution Strategies Per File Type

### Conflict Detection

A conflict occurs when both local and remote have changed since last sync:

```
fn detect_conflict(local: &FileState, remote: &FileState, last_sync: &FileState) -> bool {
    local.hash != last_sync.hash && remote.hash != last_sync.hash && local.hash != remote.hash
}
```

### Resolution Strategies

| File Type | Strategy | Rationale |
|-----------|----------|-----------|
| SQLite databases (memory_palace, telemetry) | CRDT merge | Structured data, mergeable |
| Cognitive state JSON | Last-write-wins (LWW) | Single active device at a time |
| Skills library | Union merge | Skills are additive, no conflicts |
| World model beliefs | LWW with conflict log | Beliefs are device-specific context |
| Settings/config | LWW | User explicitly sets on one device |
| Source mirror (self-mods) | Git merge (3-way) | Version-controlled by design |
| Telemetry | Append-only merge | No conflicts possible (time-indexed) |

### Last-Write-Wins Implementation

```
fn resolve_lww(local: &FileState, remote: &FileState) -> SyncAction {
    if local.modified_at > remote.modified_at {
        SyncAction::Push  // Local is newer, upload
    } else {
        SyncAction::Pull  // Remote is newer, download
    }
}
```

### Union Merge (Skills)

```
fn merge_skills(local: &SkillLibrary, remote: &SkillLibrary) -> SkillLibrary {
    let mut merged = local.clone();

    for remote_skill in &remote.skills {
        if let Some(local_skill) = merged.skills.iter_mut().find(|s| s.id == remote_skill.id) {
            // Same skill exists locally — keep the one with higher confidence
            if remote_skill.confidence > local_skill.confidence {
                *local_skill = remote_skill.clone();
            }
        } else {
            // New skill from remote — add it
            merged.skills.push(remote_skill.clone());
        }
    }

    merged
}
```

---

## CRDT Merge for Memory Palace

### The Challenge

SQLite databases can't be naively merged (binary files). But the memory palace has structured, mergeable content.

### Approach: Operation-Based CRDTs

Instead of merging database files, sync the operations (inserts, updates, deletes) and replay them:

```
struct SyncOperation {
    id: Uuid,                    // Globally unique operation ID
    timestamp: i64,              // Lamport timestamp (not wall clock)
    device_id: String,
    table: String,
    operation: OpType,
    row_id: String,
    data: Option<Vec<u8>>,       // Serialized row data
}

enum OpType {
    Insert,
    Update { column: String },
    Delete,
    SoftDelete,  // Mark as deleted, don't remove
}
```

### Merge Algorithm

```
fn merge_operations(local_ops: &[SyncOperation], remote_ops: &[SyncOperation]) -> Vec<SyncOperation> {
    let mut all_ops: Vec<_> = local_ops.iter().chain(remote_ops.iter()).collect();

    // Sort by Lamport timestamp (causal ordering)
    all_ops.sort_by_key(|op| (op.timestamp, op.device_id.clone()));

    // Deduplicate by operation ID
    all_ops.dedup_by_key(|op| op.id);

    // Apply conflict resolution per table
    let mut resolved = vec![];
    for op in all_ops {
        if let Some(conflict) = find_conflict(&resolved, op) {
            let winner = resolve_table_conflict(op.table, op, conflict);
            resolved.retain(|o| o.id != conflict.id);
            resolved.push(winner);
        } else {
            resolved.push(op.clone());
        }
    }

    resolved
}
```

### Per-Table Conflict Resolution

```
fn resolve_table_conflict(table: &str, a: &SyncOperation, b: &SyncOperation) -> SyncOperation {
    match table {
        "episodic_entries" => {
            // Episodic memories: keep both (append-only, no conflicts)
            // This shouldn't happen — episodic entries have unique IDs
            a.clone()  // Shouldn't reach here
        }
        "semantic_nodes" => {
            // Concepts: merge by taking highest activation/stability
            merge_semantic_node(a, b)
        }
        "semantic_edges" => {
            // Edges: take highest strength
            if a.strength() > b.strength() { a.clone() } else { b.clone() }
        }
        "procedural_rules" => {
            // Skills: take highest confidence
            if a.confidence() > b.confidence() { a.clone() } else { b.clone() }
        }
        "goals" => {
            // Goals: LWW (goals are device-specific context)
            if a.timestamp > b.timestamp { a.clone() } else { b.clone() }
        }
        _ => {
            // Default: LWW
            if a.timestamp > b.timestamp { a.clone() } else { b.clone() }
        }
    }
}
```

---

## Sync Queue Prioritization

### Priority Levels

Not all data is equally urgent to sync:

```
enum SyncPriority {
    Critical = 0,    // Sync immediately (settings, auth tokens)
    High = 1,        // Sync within 1 minute (cognitive state, active goals)
    Normal = 2,      // Sync within 5 minutes (memory palace, world model)
    Low = 3,         // Sync within 30 minutes (telemetry)
    Background = 4,  // Sync when idle (source mirror, large blobs)
}
```

### Queue Processing

```
struct SyncQueue {
    entries: BinaryHeap<SyncEntry>,  // Priority queue
    in_flight: HashSet<String>,      // Currently uploading
    max_concurrent: usize,           // Bounded by bandwidth
}

impl SyncQueue {
    fn process(&mut self, bandwidth: &BandwidthEstimate) {
        // Process highest priority first
        while self.in_flight.len() < self.max_concurrent {
            if let Some(entry) = self.entries.pop() {
                // Check if bandwidth allows
                if bandwidth.can_afford(entry.size_bytes) {
                    self.in_flight.insert(entry.path.clone());
                    spawn_upload(entry);
                } else {
                    // Re-queue for later
                    self.entries.push(entry);
                    break;
                }
            } else {
                break;
            }
        }
    }
}
```

### Sync Frequency by Data Type

| Data | Priority | Frequency | Typical Size |
|------|----------|-----------|-------------|
| Global settings | Critical | On change | < 1 KB |
| Cognitive state | High | Every 5 min | 50-200 KB |
| Memory palace (operations log) | Normal | Every 5 min | 10-500 KB |
| World model | Normal | Every 5 min | 20-100 KB |
| Skills library | Normal | On change | 5-50 KB |
| Telemetry | Low | Every 30 min | 1-10 MB |
| Source mirror | Background | On modification | 100 KB - 5 MB |

---

## Bandwidth Estimation

### Adaptive Bandwidth Detection

```
struct BandwidthEstimate {
    upload_bps: f64,       // Bytes per second (upload)
    download_bps: f64,     // Bytes per second (download)
    latency_ms: f64,       // Round-trip time to sync endpoint
    last_measured: Instant,
    confidence: f64,       // How recent/reliable the estimate is
}

impl BandwidthEstimate {
    fn measure(&mut self, bytes_transferred: u64, duration: Duration, direction: Direction) {
        let bps = bytes_transferred as f64 / duration.as_secs_f64();

        match direction {
            Direction::Upload => {
                // Exponential moving average
                self.upload_bps = self.upload_bps * 0.7 + bps * 0.3;
            }
            Direction::Download => {
                self.download_bps = self.download_bps * 0.7 + bps * 0.3;
            }
        }

        self.last_measured = Instant::now();
        self.confidence = 1.0;
    }

    fn can_afford(&self, bytes: u64) -> bool {
        // Don't start a transfer that would take more than 30 seconds
        let estimated_duration = bytes as f64 / self.upload_bps;
        estimated_duration < 30.0
    }

    fn decay(&mut self) {
        // Confidence decays if we haven't measured recently
        let age = self.last_measured.elapsed().as_secs_f64();
        self.confidence = (1.0 - age / 300.0).max(0.1);  // Decays over 5 minutes
    }
}
```

### Bandwidth-Aware Sync Decisions

```
fn should_sync_now(entry: &SyncEntry, bandwidth: &BandwidthEstimate) -> bool {
    match entry.priority {
        SyncPriority::Critical => true,  // Always sync critical data
        SyncPriority::High => bandwidth.upload_bps > 10_000.0,  // Need at least 10 KB/s
        SyncPriority::Normal => bandwidth.upload_bps > 50_000.0,  // Need 50 KB/s
        SyncPriority::Low => bandwidth.upload_bps > 100_000.0,  // Need 100 KB/s
        SyncPriority::Background => bandwidth.upload_bps > 500_000.0 && bandwidth.confidence > 0.8,
    }
}
```

---

## Partial Sync Recovery

### The Problem

Sync can be interrupted at any point (network loss, app close, crash). The system must recover gracefully without data loss or corruption.

### Resumable Uploads

```
struct UploadState {
    path: String,
    total_bytes: u64,
    uploaded_bytes: u64,
    chunk_size: u64,        // 1 MB chunks
    chunks_completed: Vec<u32>,  // Which chunks are confirmed
    upload_id: String,      // Server-side multipart upload ID
}

impl UploadState {
    fn resume(&self) -> u64 {
        // Find first incomplete chunk
        let next_chunk = (0..self.total_chunks())
            .find(|c| !self.chunks_completed.contains(c))
            .unwrap_or(0);
        next_chunk as u64 * self.chunk_size
    }
}
```

### Manifest Consistency

The sync manifest tracks what's been successfully synced:

```
struct SyncManifest {
    files: HashMap<String, ManifestEntry>,
    last_full_sync: i64,
    device_id: String,
    schema_version: u32,
}

struct ManifestEntry {
    path: String,
    local_hash: [u8; 32],
    remote_hash: [u8; 32],
    last_synced: i64,
    size_bytes: u64,
    status: SyncStatus,
}

enum SyncStatus {
    Synced,              // Local == Remote
    LocalNewer,          // Local changed since last sync
    RemoteNewer,         // Remote changed (another device pushed)
    Conflict,            // Both changed
    Uploading(f64),      // In progress (percentage)
    Failed(String),      // Last attempt failed (reason)
}
```

### Recovery Algorithm

On startup after interrupted sync:

```
fn recover_sync_state() -> Result<()> {
    // 1. Load local manifest
    let manifest = load_manifest()?;

    // 2. Check for incomplete uploads
    for (path, entry) in &manifest.files {
        if let SyncStatus::Uploading(_) = entry.status {
            // Check if server has partial upload
            if let Some(upload_state) = server.check_multipart(path).await? {
                // Resume from where we left off
                sync_queue.push(SyncEntry::resume(path, upload_state));
            } else {
                // Server doesn't have partial — restart upload
                entry.status = SyncStatus::LocalNewer;
            }
        }
    }

    // 3. Verify manifest consistency
    for (path, entry) in &manifest.files {
        let local_hash = compute_hash(path)?;
        if local_hash != entry.local_hash {
            // Local file changed since manifest was written
            entry.local_hash = local_hash;
            entry.status = SyncStatus::LocalNewer;
        }
    }

    // 4. Queue any pending syncs
    for (path, entry) in &manifest.files {
        if entry.status != SyncStatus::Synced {
            sync_queue.push(SyncEntry::from_manifest(path, entry));
        }
    }

    Ok(())
}
```

---

## Device Revocation Flow

### Revocation Scenarios

1. **User revokes from Settings** (on another device)
2. **Device reported stolen** (user contacts support)
3. **Automatic revocation** (device inactive > 90 days)

### Revocation Process

```
1. User initiates revocation (Settings → Devices → Revoke)
2. API invalidates the device's key derivation path
3. Revoked device's key can no longer decrypt NEW blobs
4. Existing blobs remain encrypted with old keys (still readable by other devices)
5. Optional: key rotation (re-encrypt all blobs with new master derivation)

POST /sync/devices/{device_id}/revoke
Response: { "revoked": true, "key_rotation_required": false }
```

### Key Rotation (Optional, Post-Revocation)

If the user wants to ensure the revoked device can't read ANY data (even cached):

```
fn rotate_keys() -> Result<()> {
    // 1. API generates new master key (old master is archived)
    let new_device_key = api.rotate_master_key().await?;

    // 2. Download all blobs
    let manifest = api.get_manifest().await?;

    // 3. Re-encrypt each blob with new key
    for (path, _) in &manifest.files {
        let encrypted = api.download_blob(path).await?;
        let plaintext = old_crypto.decrypt_file(&encrypted, path)?;
        let re_encrypted = new_crypto.encrypt_file(&plaintext, path)?;
        api.upload_blob(path, &re_encrypted).await?;
    }

    // 4. Update local device key
    store_device_key(new_device_key)?;

    // 5. Delete old blobs from server
    api.delete_old_blobs().await?;

    Ok(())
}
```

### Revocation Propagation

Other devices learn about revocation on next sync:

```
// During manifest sync, check device list
let devices = api.list_devices().await?;
if !devices.iter().any(|d| d.id == self.device_id) {
    // THIS device has been revoked!
    // Clear local device key
    // Show "device revoked" message to user
    // Require re-authentication
}
```

---

## Open Questions / Design Decisions

1. **Server trust model**: The API holds the master key in an HSM. This means the server CAN decrypt user data if compelled (legal order). Is this acceptable? Alternative: user-held master key (mnemonic phrase). Tradeoff: UX simplicity vs zero-trust. Current decision: server-held for UX, with clear documentation of trust model.

2. **Sync frequency tuning**: 5 minutes for memory palace — is this too frequent (bandwidth waste) or too infrequent (data loss risk)? Should it adapt based on activity level? Current plan: adaptive — sync more frequently during active use, less during idle.

3. **Offline operation**: How long can the system operate without syncing? Indefinitely — sync is backup, not dependency. But the sync queue grows. Current plan: queue up to 1000 entries, then start dropping low-priority items.

4. **Multi-device active use**: What if the user has two devices active simultaneously? Current plan: LWW for most data, CRDT for memory palace. But simultaneous active use is an edge case — the system is designed for one active device at a time.

5. **Storage backend flexibility**: Should users be able to bring their own S3 bucket? Current plan: yes (CustomS3 backend). But this adds complexity (different auth, different endpoints, different reliability).

6. **Sync visibility**: Should the user see sync status in the UI? Current plan: minimal — a small indicator showing "synced" / "syncing" / "offline". Detailed sync log available in Settings.

---

## Research References

- **Krawczyk, H. (2010)**. "Cryptographic Extraction and Key Derivation: The HKDF Scheme" — HKDF specification
- **Shapiro et al. (2011)**. "Conflict-free Replicated Data Types" — CRDT theory
- **Kleppmann, M. (2017)**. "Designing Data-Intensive Applications" — Distributed systems, conflict resolution
- **Rogaway, P. (2011)**. "Evaluation of Some Blockcipher Modes of Operation" — AES-GCM analysis
- **Relevant crates**: `aes-gcm` (encryption), `hkdf` (key derivation), `sha2` (HKDF-SHA256), `reqwest` (HTTP for S3), `rusoto_s3` or `aws-sdk-s3` (S3 client), `blake3` (fast hashing for manifests)

---

## Edge Cases and Failure Modes

1. **Clock skew**: LWW depends on timestamps. If device clocks are significantly different, wrong version wins. Mitigation: use Lamport timestamps (logical clocks) for ordering, wall clock only for display.

2. **Large file sync**: Source mirror after many self-modifications could be large (>100MB). Mitigation: incremental sync (only changed files within the git repo), compression before encryption.

3. **Network partition during sync**: Upload succeeds but manifest update fails. Mitigation: server-side manifest is authoritative. Client re-syncs manifest on next connection.

4. **Encryption key loss**: If the API loses the master key (catastrophic server failure). Mitigation: HSM with backup. If truly lost, user data is unrecoverable. This is documented in the trust model.

5. **Sync loop**: Device A pushes, Device B pulls and pushes back (modified), Device A pulls and pushes back... Mitigation: sync operations are idempotent. Same content = same hash = no re-upload.

6. **Quota exhaustion**: User exceeds storage quota (5GB free tier). Mitigation: sync queue pauses, user notified, oldest telemetry data offered for deletion.

---

## Interaction with Other Subsystems

- **Memory Palace**: Primary sync target. CRDT merge ensures memory consistency across devices.
- **Cognitive Homeostasis**: Journal snapshots are synced for disaster recovery. Recovery on new device uses synced snapshots.
- **Self-Modification**: Source mirror is synced. Self-modifications on one device are available on another (via git merge).
- **Telemetry**: Synced at low priority. Enables cross-device telemetry analysis.
- **LLM Pool**: Provider configurations sync via global settings. API tokens sync (encrypted).
- **Hardware Scaling**: Sync frequency adapts to bandwidth (hardware-scaling provides the bandwidth estimate).
- **Settings UI**: Sync status, device management, and backend configuration are all in Settings → Sync & Backup.
