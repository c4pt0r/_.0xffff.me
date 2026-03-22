function setPrismTheme(theme) {
    const light = document.getElementById('prism-light');
    const dark = document.getElementById('prism-dark');
    if (!light || !dark) return;

    if (theme === 'light') {
        light.disabled = false;
        dark.disabled = true;
    } else {
        light.disabled = true;
        dark.disabled = false;
    }
}

function toggleTheme(theme) {
    document.body.classList.remove('light-theme', 'dark-theme');
    document.body.classList.add(`${theme}-theme`);

    setPrismTheme(theme);
    localStorage.setItem('theme', theme);
}

window.addEventListener('load', () => {
    const savedTheme = localStorage.getItem('theme') || 'dark';
    document.body.classList.add(`${savedTheme}-theme`);
    setPrismTheme(savedTheme);
});

