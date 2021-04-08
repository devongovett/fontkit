import fontkit from '../src';
import assert from 'assert';

describe('opentype', function() {
  let font = fontkit.openSync(__dirname + '/data/SourceSansPro/SourceSansPro-Regular.otf');

  it('featureParams nameID of stylistic set should be 257', function() {
    assert.equal(font.GSUB.featureList[150].feature.featureParams.nameID, 257);
  });

  it('featureParams version of stylistic set should be 0', function() {
    assert.equal(font.GSUB.featureList[150].feature.featureParams.version, 0);
  });

  it('featureParams should be null of aalt opentype feature', function() {
    assert.equal(font.GSUB.featureList[1].feature.featureParams, null);
  });

});
