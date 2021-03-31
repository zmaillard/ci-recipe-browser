const webpack = require("webpack");
const { merge } = require("webpack-merge");
const baseConfig = require("./base.config");
const path = require("path");

module.exports = merge(baseConfig, {
  mode: "development",
  plugins: [new webpack.HotModuleReplacementPlugin()],
  module: {
    devServer: {
      inline: true,
      hot: true,
      stats: "errors-only",
      contentBase: path.join(__dirname, "src"),
    },
  },
});
