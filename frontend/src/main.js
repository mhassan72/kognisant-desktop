import { createApp } from "vue";
import "./style.css";
import App from "./App.vue";
import router from "./router";

/**
 * Kognisant Core Frontend Entry Point
 *
 * Responsibility: Initializes the Vue 3 application,
 * injects the routing system, and mounts to the DOM.
 */

const app = createApp(App);

app.use(router);

app.mount("#app");
