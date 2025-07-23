class DocumentManager {
    constructor() {
        this.docs = new Map();
    }

    async load(path) {
        const content = document.getElementById('content');
        content.innerHTML = '<div class="loading">Loading...</div>';

        try {
            let docContent;

            if (this.docs.has(path)) {
                docContent = this.docs.get(path);
            } else {
                const response = await fetch(path);
                if (!response.ok) {
                    throw new Error(`Failed to load ${path}: ${response.status}`);
                }
                docContent = await response.text();
                this.docs.set(path, docContent);
            }

            const html = marked.parse(docContent);
            const sanitizedHtml = DOMPurify.sanitize(html);
            content.innerHTML = sanitizedHtml;

            this.enhanceContent();
            history.pushState({ path }, '', `#${path}`);

        } catch (error) {
            console.error('Error loading document:', error);
            content.innerHTML = `
                <div class="error">
                    <h1>Error Loading Document</h1>
                    <p>Failed to load: ${path}</p>
                    <div class="error-details">${error.message}</div>
                    <button class="retry-btn" onclick="app.loadDocument('${path}')">Retry</button>
                </div>
            `;
        }
    }

    enhanceContent() {
        this.highlightCode();
        this.addCopyButtons();
        this.generateTableOfContents();
    }

    highlightCode() {
        const dreamCodeBlocks = document.querySelectorAll('code[class*="language-dream"], pre code');
        dreamCodeBlocks.forEach(block => {
            if (block.textContent.includes('dream ') || block.parentElement.className.includes('language-dream')) {
                block.className = 'language-dream';
                block.parentElement.className = 'language-dream';

                let html = block.innerHTML;
                const keywords = ['dream', 'let', 'const', 'if', 'else', 'for', 'while', 'class', 'return', 'new', 'this', 'in'];

                keywords.forEach(keyword => {
                    const regex = new RegExp(`\\b${keyword}\\b`, 'g');
                    html = html.replace(regex, `<span class="token keyword">${keyword}</span>`);
                });

                html = html.replace(/"([^"]*)"/g, '<span class="token string">"$1"</span>');
                html = html.replace(/\/\/([^\n]*)/g, '<span class="token comment">//$1</span>');
                html = html.replace(/\b(\d+\.?\d*)\b/g, '<span class="token number">$1</span>');
                html = html.replace(/(\w+)\s*\(/g, '<span class="token function">$1</span>(');

                block.innerHTML = html;
            }
        });
    }

    addCopyButtons() {
        const codeBlocks = document.querySelectorAll('pre');
        codeBlocks.forEach(block => {
            const button = document.createElement('button');
            button.className = 'copy-btn';
            button.textContent = 'Copy';
            button.addEventListener('click', () => {
                const code = block.querySelector('code');
                const text = code ? code.textContent : block.textContent;
                navigator.clipboard.writeText(text).then(() => {
                    button.textContent = 'Copied!';
                    setTimeout(() => {
                        button.textContent = 'Copy';
                    }, 2000);
                });
            });
            block.style.position = 'relative';
            block.appendChild(button);
        });
    }

    generateTableOfContents() {
        const toc = document.getElementById('table-of-contents');
        const headings = document.querySelectorAll('#content h1, #content h2, #content h3, #content h4');

        if (headings.length === 0) {
            toc.innerHTML = '<p style="color: var(--text-muted); font-style: italic;">No headings found</p>';
            return;
        }

        const tocList = document.createElement('ul');

        headings.forEach((heading, index) => {
            const level = parseInt(heading.tagName.charAt(1));
            const id = `heading-${index}`;
            heading.id = id;

            const li = document.createElement('li');
            const a = document.createElement('a');
            a.href = `#${id}`;
            a.textContent = heading.textContent;
            a.className = `toc-level-${level}`;

            a.addEventListener('click', (e) => {
                e.preventDefault();
                heading.scrollIntoView({ behavior: 'smooth', block: 'start' });
            });

            li.appendChild(a);
            tocList.appendChild(li);
        });

        toc.innerHTML = '';
        toc.appendChild(tocList);
    }

    updateBreadcrumbs(path, navigationManager) {
        const breadcrumbs = document.getElementById('breadcrumbs');
        const pathParts = path.split('/');
        const fileName = pathParts[pathParts.length - 1].replace('.md', '');

        const found = navigationManager.findItemByPath(path);

        if (found) {
            breadcrumbs.innerHTML = `
                <span>${found.section.title}</span>
                <span class="separator">›</span>
                <span class="current">${found.item.title}</span>
            `;
        } else {
            breadcrumbs.innerHTML = `<span class="current">${fileName}</span>`;
        }
    }
}

export default DocumentManager;