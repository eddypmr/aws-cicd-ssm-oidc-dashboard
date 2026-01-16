async function fetchJson(path) {
    const r = await fetch(path, {cache: "no-store"});
    if (!r.ok) throw new Error(`${path} -> ${r.status}`);
    return await r.json();
}

function pretty(obj) {
    return JSON.stringify(obj, null, 2);
}

async function refresh() {
    const map = [
        ["/health", "health"],
        ["/version", "version"],
        ["/system", "system"],
        ["/docker", "docker"]
    ];

    for (const [path, id] of map) {
        const el = document.getElementById(id);
        el.textContent = "Loading...";

        try {
            const data = await fetchJson(path);
            el.textContent = pretty(data);
        } catch (e) {
            el.textContent = `Error: ${e}`;
        }
    }
}

document.getElementById("refresh").addEventListener("click", refresh);
refresh();