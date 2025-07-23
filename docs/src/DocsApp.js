import ThemeManager from './managers/ThemeManager.js';
import NavigationManager from './managers/NavigationManager.js';
import SearchManager from './managers/SearchManager.js';
import DocumentManager from './managers/DocumentManager.js';
import UIManager from './managers/UIManager.js';

class DocsApp {
    constructor() {
        this.themeManager = new ThemeManager();
        this.navigationManager = new NavigationManager();
        this.searchManager = new SearchManager(this.navigationManager);
        this.documentManager = new DocumentManager();
        this.uiManager = new UIManager();

        this.initialize();
    }

    async initialize() {
        this.themeManager.apply();
        await this.navigationManager.load();
        this.navigationManager.render((path, activeLink) => this.loadDocument(path, activeLink));
        this.searchManager.buildIndex();
        this.searchManager.setupUI((path) => this.loadDocument(path));
        this.uiManager.setupDropdowns();
        this.uiManager.setDropdownItemClickHandler((path) => this.loadDocument(path));
        this.setupBrowserNavigation();
        this.handleInitialRoute();
    }

    async loadDocument(path, activeLink = null) {
        await this.documentManager.load(path);
        this.documentManager.updateBreadcrumbs(path, this.navigationManager);
        
        if (!activeLink) {
            activeLink = document.querySelector(`a[href="#${path}"]`);
        }
        this.navigationManager.updateActiveItem(activeLink);
    }

    setupBrowserNavigation() {
        window.addEventListener('popstate', () => {
            this.handleInitialRoute();
        });
    }

    handleInitialRoute() {
        const hash = window.location.hash.substring(1);
        if (hash) {
            this.loadDocument(hash);
        } else {
            const firstItem = this.navigationManager.getFirstItem();
            if (firstItem) {
                this.loadDocument(firstItem.path);
            }
        }
    }

    toggleTheme() {
        this.themeManager.toggle();
    }
}

export default DocsApp;