username_input = document.getElementById("username_input");
service_switch = document.getElementById("service_switch");
token_div = document.getElementById("token");

token_div.style.display = "none";
username_input.addEventListener("keyup", function(e) {
  if (!service_switch.checked) {
    if (e.keyCode === 13) {
      e.preventDefault();
      token_div.style.display = "flex";
    }
  }
});

service_switch.addEventListener("change", function(e) {
  if (e.currentTarget.checked) {
    token_div.style.display = "none";
  }
});