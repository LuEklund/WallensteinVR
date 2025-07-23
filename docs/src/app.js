import DocsApp from './DocsApp.js';

// Initialize the app
const app = new DocsApp();

// Theme toggle function - make it globally available
window.toggleTheme = function() {
    app.toggleTheme();
};

// Also make app globally available for debugging
window.app = app;