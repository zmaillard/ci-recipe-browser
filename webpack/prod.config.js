const webpack = require("webpack");
const { merge } = require("webpack-merge");
const baseConfig = require("./base.config");
const path = require("path");

module.exports = merge(baseConfig, {
  mode: "production",

  output: {
      path: path.resolve('./dist'),
  }

});
