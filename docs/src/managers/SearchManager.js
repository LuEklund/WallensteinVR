class SearchManager {
    constructor(navigationManager) {
        this.navigationManager = navigationManager;
        this.searchIndex = [];
    }

    buildIndex() {
        this.searchIndex = [];
        this.navigationManager.navigation.forEach(section => {
            section.items.forEach(item => {
                this.searchIndex.push({
                    title: item.title,
                    path: item.path,
                    section: section.title
                });
            });
        });
    }

    search(query) {
        return this.searchIndex.filter(item =>
            item.title.toLowerCase().includes(query.toLowerCase()) ||
            item.section.toLowerCase().includes(query.toLowerCase())
        );
    }

    setupUI(onResultClick) {
        const searchInput = document.getElementById('search-input');
        const searchResults = document.getElementById('search-results');

        searchInput.addEventListener('input', (e) => {
            const query = e.target.value.trim();

            if (query.length === 0) {
                searchResults.style.display = 'none';
                return;
            }

            const results = this.search(query);
            this.renderResults(results, searchResults, onResultClick);
        });

        document.addEventListener('click', (e) => {
            if (!e.target.closest('.search-container')) {
                searchResults.style.display = 'none';
            }
        });
    }

    renderResults(results, container, onResultClick) {
        container.innerHTML = '';

        if (results.length === 0) {
            const noResults = document.createElement('div');
            noResults.className = 'no-results';
            noResults.textContent = 'No results found';
            container.appendChild(noResults);
        } else {
            results.forEach(result => {
                const div = document.createElement('div');
                div.className = 'search-result';
                div.innerHTML = `<strong>${result.title}</strong><br><small>${result.section}</small>`;
                div.addEventListener('click', () => {
                    onResultClick(result.path);
                    container.style.display = 'none';
                    document.getElementById('search-input').value = '';
                });
                container.appendChild(div);
            });
        }

        container.style.display = 'block';
    }
}

export default SearchManager;