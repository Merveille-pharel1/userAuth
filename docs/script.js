const form = document.querySelector("form");

const sign_in = document.getElementById("sign-in");
const sign_up = document.getElementById("sign-up");
const pCreate = document.querySelector(".create-account");
const pConnect = document.querySelector(".connect-account");
const div_connection = document.querySelector(".Connexion");
const div_new = document.querySelector(".new-Account");

pCreate.onclick = switchDisplay;
pConnect.onclick = switchDisplay;

sign_in.onclick = async function(event){
    event.preventDefault();

    const userName = event.target.parentNode.querySelector("#name1");
    const pwd = event.target.parentNode.querySelector("#password");

    // Construire un corps JSON et appeler la route POST /user du serveur
    const payload = {
        name: userName.value,
        password: pwd.value
    };

    const options = {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
    };

    const response = await fetch('/user', options);

    if (response.status === 200) {
        alert("Connexion réussie");
        form.reset();
    } else {
        const text = await response.text();

        if (text && text.length > 0)
            alert(text);
        
        else if (response.status === 401) 
            alert("Nom ou mot de passe incorrect!");
        
        else 
            alert('Erreur lors de la connexion');
        
    }
};

sign_up.onclick = async function(event){
    event.preventDefault();

    const userName = event.target.parentNode.querySelector("#name2");
    const pwd1 = event.target.parentNode.querySelector("#password1");
    const pwd2 = event.target.parentNode.querySelector("#password2");

    if (pwd1.value !== pwd2.value) {
        alert("Mot de passe invalide!");
        return;
    }

    // On poste vers /new-user et laisse le serveur vérifier l'existence
    const newUser = {
        name: userName.value,
        password: pwd1.value
    };

    const options = {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(newUser)
    };

    const response = await fetch('/new-user', options);

    if (response.status === 201) {
        alert("Utilisateur ajouté");
        form.reset();
    } else {
        // lire le message d'erreur retourné par le serveur
        const text = await response.text();
        alert(text || 'Erreur lors de la création');
    }
};

function switchDisplay(){
    pConnect.classList.toggle("d-none");
    pCreate.classList.toggle("d-none");
    div_connection.classList.toggle("d-none");
    div_new.classList.toggle("d-none");
}




