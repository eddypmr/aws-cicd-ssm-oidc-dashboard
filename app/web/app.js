async function run() {
    const out = document.getElementById('out');
    try {
        const r = await fetch('/health');
        const data = await r.json();
        out.textContent = JSON.stringify(data, null, 2);
    } catch (e) {
        out.textContent = "Error" + e;
    }
}
run();