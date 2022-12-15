import { createAuth0Client } from "@auth0/auth0-spa-js";

const buildAuthToken = (accessToken, user) => {
  let result = { err: null, ok: null };
  if (accessToken != null && user != null) {
    const emailAddress = user.email;
    const phoneNumber = user["http://sagebrushgis.com/phone_number"];
    result.ok = {
      profile: { emailAddress, phoneNumber },
      token: accessToken,
    };
  } else {
    result.err = { name: "Authentication Failure" };
  }

  return result;
};

(async function () {
  const auth0 = await createAuth0Client({
    domain: process.env.AUTH0_DOMAIN,
    clientId: process.env.AUTH0_CLIENT_ID,
    authorizationParams: {
      redirect_uri: process.env.AUTH0_REDIRECT_URI,
      audience: "https://bot.recipesear.ch",
    },
  });

  const storedProfile = localStorage.getItem("profile");
  const storedToken = localStorage.getItem("token");

  const authToken = buildAuthToken(
    storedToken,
    storedProfile ? JSON.parse(storedProfile) : null
  );

  var Elm = require("../src/elm/Main.elm").Elm;
  var elmApp = Elm.Main.init({
    node: document.getElementById("main"),
    flags: {
      searchServiceUrl: process.env.SEARCH_SERVICE,
      searchApiKey: process.env.SEARCH_KEY,
      initialUser: authToken,
    },
  });

  elmApp.ports.auth0Logout.subscribe(function (opts) {
    localStorage.removeItem("profile");
    localStorage.removeItem("token");
  });

  elmApp.ports.auth0Authorize.subscribe(async function (opts) {
    await auth0.loginWithRedirect();
  });

  elmApp.ports.pageLoaded.subscribe(async function (opts) {
    if (window.location.href.indexOf("/callback") >= 0) {
      const redirectResult = await auth0.handleRedirectCallback();
      const accessToken = await auth0.getTokenSilently();

      const user = await auth0.getUser();
      if (accessToken && user) {
        localStorage.setItem("profile", JSON.stringify(user));
        localStorage.setItem("token", accessToken);
      }

      const authToken = buildAuthToken(accessToken, user);

      elmApp.ports.auth0authResult.send(authToken);
    }
  });
})();

/*
email: "sagebrushgis@gmail.com"
email_verified: true
name: "sagebrushgis@gmail.com"
nickname: "sagebrushgis"
picture: "https://s.gravatar.com/avatar/97c2bf408d95d356d272b9104fcd8e8a?s=480&r=pg&d=https%3A%2F%2Fcdn.auth0.com%2Favatars%2Fsa.png"
sub: "auth0|5addcf175fb3bc1b6d7b6779"
updated_at: "2022-12-13T14:04:18.214Z"
http://sagebrushgis.com/phone_number
*/
