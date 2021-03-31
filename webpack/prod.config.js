const webpack = require("webpack");
const { mergeWithRules } = require("webpack-merge");
const baseConfig = require("./base.config");
const path = require("path");

const mergeRules = {
  module: {
    rules: {
      test: "match",
      use: {
        loader: "match",
        options: "replace",
      },
    },
  },
};

module.exports = mergeWithRules(mergeRules)(baseConfig, {
  mode: "production",
  output: {
    path: path.resolve("./dist"),
  },
  module: {
    rules: [
      {
        test: /\.elm$/,
        use: {
          loader: "elm-webpack-loader",
          options: {
            optimize: true,
          },
        },
      },
    ],
  },
});
