(function () {
    // Prevent the script from being executed twice (avoids duplicate `const` errors)
    if (window.__userAuthScriptLoaded) return;
    window.__userAuthScriptLoaded = true;

    const form = document.querySelector('form');

    const signInBtn = document.getElementById('sign-in');
    const signUpBtn = document.getElementById('sign-up');
    const pCreate = document.querySelector('.create-account');
    const pConnect = document.querySelector('.connect-account');
    const divConnection = document.querySelector('.Connexion');
    const divNew = document.querySelector('.new-Account');

    if (pCreate) pCreate.onclick = switchDisplay;
    if (pConnect) pConnect.onclick = switchDisplay;

    if (signInBtn) signInBtn.onclick = async function (event) {
    event.preventDefault();

        const parent = event.currentTarget.closest('form') || event.target.parentNode;
        const userName = parent.querySelector('#name1');
        const pwd = parent.querySelector('#password');

    // Construire un corps JSON et appeler la route POST /user du serveur
    const payload = {
        name: userName.value,
        password: pwd.value
    };

        const options = {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'same-origin',
            body: JSON.stringify(payload),
    };

        try {
            const response = await fetch('/login', options);

        // If server replies with JSON (API path), follow redirect field
        const contentType = response.headers.get('content-type') || '';
        if (contentType.includes('application/json')) {
            const data = await response.json().catch(() => ({}));
            if (data && data.redirect) {
                window.location.href = data.redirect;        
                return;
            }
            if (response.ok) {
                alert('Connexion réussie');
                if (form) form.reset();
            } else {
                alert(data && data.error ? data.error : 'Erreur lors de la connexion');
            }
        } else if (response.status === 303) {
            const location = response.headers.get('location');
            if (location) window.location.href = location;
        } else {
            const text = await response.text();
            if (text && text.length > 0) {
                alert(text);
            } else {
                alert('Erreur lors de la connexion');
            }
        }
        } catch (err) {
            console.error(err);
            alert('Erreur réseau lors de la connexion');
        }
    };

    if (signUpBtn) signUpBtn.onclick = async function (event) {
        event.preventDefault();

        const parent = event.currentTarget.closest('form') || event.target.parentNode;
        const userName = parent.querySelector('#name2');
        const pwd1 = parent.querySelector('#password1');
        const pwd2 = parent.querySelector('#password2');

        if (!pwd1 || !pwd2 || pwd1.value !== pwd2.value) {
            alert('Mot de passe invalide!');
            return;
        }

        // On poste vers /new-user et laisse le serveur vérifier l'existence
        const newUser = { name: userName.value, password: pwd1.value };

        const options = {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            credentials: 'same-origin',
            body: JSON.stringify(newUser),
        };

        try {
            const response = await fetch('/new-user', options);
            const contentType = response.headers.get('content-type') || '';
            if (contentType.includes('application/json')) {
                const data = await response.json().catch(() => ({}));
                if (data && data.redirect) {
                    window.location.href = data.redirect;
                    return;
                }
                if (response.status === 201) {
                    alert('Utilisateur ajouté');
                    if (form) form.reset();
                } else {
                    alert(data && data.error ? data.error : 'Erreur lors de la création');
                }
            } else if (response.status === 303) {
                const location = response.headers.get('location');
                if (location) window.location.href = location;
            } else {
                const text = await response.text();
                alert(text || 'Erreur lors de la création');
            }
        } catch (err) {
            console.error(err);
            alert('Erreur réseau lors de la création');
        }
    };

function switchDisplay() {
    pConnect.classList.toggle('d-none');
    pCreate.classList.toggle('d-none');
    divConnection.classList.toggle('d-none');
    divNew.classList.toggle('d-none');
}


// Load current member info for the dashboard
async function loadMember() {
    try {
        const resp = await fetch('/me', { credentials: 'same-origin' });
        if (resp.status === 200) {
            const data = await resp.json();
            const nameEl = document.getElementById('member-name');
            const sinceEl = document.getElementById('member-since');
            if (nameEl) nameEl.textContent = data.name || 'Inconnu';

            const created = data.created_at || null;
            if (created && sinceEl) {
                const d = new Date(created);
                sinceEl.textContent = 'Membre depuis ' + d.toLocaleDateString();
            } else if (sinceEl) {
                sinceEl.textContent = '';
            }
        } else if (resp.status === 401) {
            const nameEl = document.getElementById('member-name');
            const sinceEl = document.getElementById('member-since');
            if (nameEl) nameEl.textContent = 'Non connecté';
            if (sinceEl) sinceEl.textContent = '';
        } else {
            const nameEl = document.getElementById('member-name');
            const sinceEl = document.getElementById('member-since');
            if (nameEl) nameEl.textContent = 'Erreur';
            if (sinceEl) sinceEl.textContent = '';
        }
    } catch (err) {
        console.error(err);
        const nameEl = document.getElementById('member-name');
        if (nameEl) nameEl.textContent = 'Erreur réseau';
    }
}


// Attach handlers on DOM ready
window.addEventListener('DOMContentLoaded', () => {
    // populate dashboard if present
    loadMember();

    const logoutBtn = document.getElementById('logout-btn');
    if (logoutBtn) {
        logoutBtn.onclick = async function (e) {
            e.preventDefault();
            try {
                const resp = await fetch('/logout', { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json' } });
                const contentType = resp.headers.get('content-type') || '';
                if (contentType.includes('application/json')) {
                    const data = await resp.json().catch(() => ({}));
                    if (data && data.redirect) {
                        window.location.href = data.redirect;
                        return;
                    }
                }
                if (resp.status === 303) {
                    const loc = resp.headers.get('location');
                    if (loc) window.location.href = loc;
                } else {
                    // fallback: go to index
                    window.location.href = '/';
                }
            } catch (err) {
                console.error(err);
                window.location.href = '/';
            }
        };
    }
});

})();

