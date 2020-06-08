import babel from 'rollup-plugin-babel';
import localResolve from 'rollup-plugin-local-resolve';
import json from 'rollup-plugin-json';

function createConfig(filename, browserlist, suffix = '') {
  return {
    input: `src/${filename}`,
    output: {
      file: `${filename}${suffix}.js`,
      format: 'cjs',
      sourcemap: true
    },
    external: [
      'restructure',
      'tiny-inflate',
      'brotli/decompress',
      'unicode-properties',
      'clone',
      'deep-equal',
      'unicode-trie',
      'dfa',
      'restructure/src/utils'
    ],
    plugins: [
      localResolve(),
      json(),
      babel({
        presets: [
          [
            '@babel/preset-env', 
            {
              modules: false,
              targets: {
                browsers: browserlist
              }
            }
          ]
        ],
        plugins: [
          [
            '@babel/plugin-proposal-decorators',
            {
              legacy: true
            }
          ],
          '@babel/plugin-proposal-class-properties'
        ]
      })
    ]
  }
}

const modernBrowsers = [
  'Firefox 57',
  'Chrome 60',
  'iOS 10',
  'Safari 10'
];

const legacyBrowsers = [
  'ie 11'
];

export default [
  createConfig('base', modernBrowsers),
  createConfig('index', modernBrowsers),
  createConfig('base', legacyBrowsers, '.es5'),
  createConfig('index', legacyBrowsers, '.es5')
];
