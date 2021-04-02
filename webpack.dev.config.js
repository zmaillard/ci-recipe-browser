const { merge } = require("webpack-merge");
const baseConfig = require("./webpack.base.config");
module.exports = merge(baseConfig, {
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
