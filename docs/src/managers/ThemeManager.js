class ThemeManager {
    constructor() {
        this.currentTheme = localStorage.getItem('theme') || 'light';
    }

    toggle() {
        this.currentTheme = this.currentTheme === 'light' ? 'dark' : 'light';
        localStorage.setItem('theme', this.currentTheme);
        this.apply();
    }

    apply() {
        const themeCSS = document.getElementById('theme-css');
        const themeToggle = document.querySelector('.theme-toggle');

        if (this.currentTheme === 'dark') {
            themeCSS.href = 'src/index-dark.css';
            themeToggle.textContent = '☀️';
            document.documentElement.setAttribute('data-theme', 'dark');
        } else {
            themeCSS.href = 'src/index.css';
            themeToggle.textContent = '🌙';
            document.documentElement.setAttribute('data-theme', 'light');
        }
    }
}

export default ThemeManager;