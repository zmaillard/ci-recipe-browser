require('dotenv').config();

const webpack = require("webpack");
const path = require("path");
const HtmlWebpackPlugin = require("html-webpack-plugin");

module.exports = {
  entry: {
    main: path.join(__dirname, "./src/index.js"),
  },
  module: {
    rules: [
      {
        test: /\.jsx?$/,
        loader: 'babel-loader',
        exclude: [
          /node_modules/,
        ],
      },
    ]
  },
  plugins: [
    new webpack.EnvironmentPlugin(["SEARCH_KEY", "SEARCH_SERVICE"]),
    new HtmlWebpackPlugin({
      template: "src/assets/index.html",
      inject: "body",
      filename: "index.html",
    }),
  ],
};
