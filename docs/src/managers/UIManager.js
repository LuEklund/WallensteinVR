class UIManager {
    setupDropdowns() {
        const dropdowns = document.querySelectorAll('.dropdown');

        dropdowns.forEach(dropdown => {
            const toggle = dropdown.querySelector('.dropdown-toggle');
            const menu = dropdown.querySelector('.dropdown-menu');

            if (toggle && menu) {
                toggle.addEventListener('click', (e) => {
                    e.preventDefault();
                    e.stopPropagation();

                    dropdowns.forEach(otherDropdown => {
                        if (otherDropdown !== dropdown) {
                            otherDropdown.classList.remove('active');
                        }
                    });

                    dropdown.classList.toggle('active');
                });

                const dropdownItems = menu.querySelectorAll('.dropdown-item');
                dropdownItems.forEach(item => {
                    item.addEventListener('click', (e) => {
                        const href = item.getAttribute('href');
                        if (href && href.startsWith('#docs/')) {
                            e.preventDefault();
                            const path = href.substring(1);
                            this.onDropdownItemClick(path);
                            dropdown.classList.remove('active');
                        }
                    });
                });
            }
        });

        document.addEventListener('click', (e) => {
            if (!e.target.closest('.dropdown')) {
                dropdowns.forEach(dropdown => {
                    dropdown.classList.remove('active');
                });
            }
        });
    }

    setDropdownItemClickHandler(handler) {
        this.onDropdownItemClick = handler;
    }
}

export default UIManager;