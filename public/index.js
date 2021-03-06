var Elm = require("../src/elm/Main.elm").Elm;

var app = Elm.Main.init({
  node: document.getElementById("main"),
  flags: {
    searchServiceUrl: process.env.SEARCH_SERVICE,
    searchApiKey: process.env.SEARCH_KEY,
  },
});