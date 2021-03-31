const path = require("path");
const webpack = require("webpack");

module.exports = () => ({
  module: {
    rules: [
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        use: [
          { loader: "elm-hot-webpack-loader" },
          {
            loader: "elm-webpack-loader",
            options: {
              cwd: __dirname,
              debug: false,
            },
          },
        ],
      },
    ],
  },
});
