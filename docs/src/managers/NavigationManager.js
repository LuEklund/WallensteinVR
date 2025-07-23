class NavigationManager {
    constructor() {
        this.navigation = [];
    }

    async load() {
        try {
            const response = await fetch('documents/navigation.json');
            if (response.ok) {
                const navData = await response.json();
                this.navigation = this.transformNavigation(navData);
            } else {
                this.generateDefaultNavigation();
            }
        } catch (error) {
            console.error('Failed to load navigation:', error);
            this.generateDefaultNavigation();
        }
    }

    transformNavigation(navData) {
        return navData.sections.map(section => ({
            title: section.title,
            items: section.items.map(item => ({
                title: item.title,
                path: `documents/${item.file}`
            }))
        }));
    }

    generateDefaultNavigation() {
        this.navigation = [
            {
                title: "Getting Started",
                items: [
                    { title: "Introduction", path: "documents/introduction.md" },
                    { title: "Installation", path: "documents/installation.md" },
                    { title: "Quick Start", path: "documents/quick-start.md" }
                ]
            },
            {
                title: "Development Guides",
                items: [
                    { title: "Architecture", path: "documents/guides/architecture.md" },
                    { title: "Shader System", path: "documents/guides/shaders.md" },
                    { title: "Debugging", path: "documents/guides/debugging.md" },
                    { title: "Troubleshooting", path: "documents/guides/troubleshooting.md" }
                ]
            },
            {
                title: "API Reference",
                items: [
                    { title: "API Overview", path: "documents/api/overview.md" }
                ]
            },
            {
                title: "Examples",
                items: [
                    { title: "Basic VR App", path: "documents/examples/basic-vr.md" },
                    { title: "Custom Shaders", path: "documents/examples/custom-shaders.md" }
                ]
            },
            {
                title: "Community",
                items: [
                    { title: "Community Hub", path: "documents/community/index.md" },
                    { title: "Contributing", path: "documents/community/contributing.md" },
                    { title: "Support", path: "documents/community/support.md" }
                ]
            },
            {
                title: "Resources",
                items: [
                    { title: "All Resources", path: "documents/resources/index.md" }
                ]
            },
            {
                title: "Downloads",
                items: [
                    { title: "Latest Release", path: "documents/downloads/index.md" }
                ]
            }
        ];
    }

    render(onItemClick) {
        const nav = document.getElementById('navigation');
        nav.innerHTML = '';

        this.navigation.forEach(section => {
            const sectionDiv = document.createElement('div');
            sectionDiv.className = 'nav-section';

            const sectionTitle = document.createElement('h3');
            sectionTitle.textContent = section.title;
            sectionDiv.appendChild(sectionTitle);

            const ul = document.createElement('ul');
            section.items.forEach(item => {
                const li = document.createElement('li');
                const a = document.createElement('a');
                a.href = `#${item.path}`;
                a.textContent = item.title;
                a.addEventListener('click', (e) => {
                    e.preventDefault();
                    onItemClick(item.path, a);
                });
                li.appendChild(a);
                ul.appendChild(li);
            });

            sectionDiv.appendChild(ul);
            nav.appendChild(sectionDiv);
        });
    }

    updateActiveItem(activeLink) {
        document.querySelectorAll('.nav a').forEach(link => {
            link.classList.remove('active');
        });

        if (activeLink) {
            activeLink.classList.add('active');
        }
    }

    findItemByPath(path) {
        for (const section of this.navigation) {
            for (const item of section.items) {
                if (item.path === path) {
                    return { item, section };
                }
            }
        }
        return null;
    }

    getFirstItem() {
        return this.navigation.length > 0 && this.navigation[0].items.length > 0 
            ? this.navigation[0].items[0] 
            : null;
    }
}

export default NavigationManager;