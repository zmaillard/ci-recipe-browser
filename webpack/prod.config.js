const webpack = require("webpack");

module.exports = () => ({
  output: {
    filename: "[name].[contenthash].js",
  },
  module: {
    rules: [
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        use: [
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
  optimization: {
    minimizer: [
      // https://elm-lang.org/0.19.0/optimize
      new TerserPlugin({
        extractComments: false,
        terserOptions: {
          mangle: false,
          compress: {
            pure_funcs: [
              "F2",
              "F3",
              "F4",
              "F5",
              "F6",
              "F7",
              "F8",
              "F9",
              "A2",
              "A3",
              "A4",
              "A5",
              "A6",
              "A7",
              "A8",
              "A9",
            ],
            pure_getters: true,
            keep_fargs: false,
            unsafe_comps: true,
            unsafe: true,
          },
        },
      }),
      new TerserPlugin({
        extractComments: false,
        terserOptions: { mangle: true },
      }),
    ],
  },
});
