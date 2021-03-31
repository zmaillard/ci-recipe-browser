const path = require("path");
const webpackMerge = require("webpack-merge");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const CopyWebpackPlugin = require("copy-webpack-plugin");

const modeConfig = (env) => require(`./webpack/${env}.config.js`)(env);
module.exports = ({ mode } = { mode: "production" }) => {
  return webpackMerge(
    {
      mode,

      entry: {
        main: path.join(__dirname, "./src/index.js"),
      },

      plugins: [
        new HtmlWebpackPlugin({
          template: "src/assets/index.html",
          inject: "body",
          filename: "index.html",
        }),
      ],
    },
    modeConfig(mode)
  );
};
