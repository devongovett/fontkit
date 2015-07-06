GSUBProcessor = require '../opentype/GSUBProcessor'
GPOSProcessor = require '../opentype/GPOSProcessor'
GlyphInfo = require '../opentype/GlyphInfo'
Shapers = require '../opentype/shapers'
AATFeatureMap = require '../aat/AATFeatureMap'
AATMorxProcessor = require '../aat/AATMorxProcessor'
KernProcessor = require './KernProcessor'
UnicodeLayoutEngine = require './UnicodeLayoutEngine'
GlyphRun = require './GlyphRun'
Script = require './Script'
unicode = require 'unicode-properties'

class LayoutEngine
  constructor: (@font) ->
        
  layout: (string, features = [], script, language) ->
    # Make the userFeatures parameter optional
    if typeof features is 'string'
      script = features
      language = script
      features = []
    
    # Map string to glyphs if needed
    if typeof string is 'string'
      # Attempt to detect the script from the string if not provided.
      script ?= Script.forString string
      glyphs = @font.glyphsForString string
    else
      # Attempt to detect the script from the glyph code points if not provided.
      unless script?
        codePoints = []
        for glyph in string
          codePoints.push glyph.codePoints...
        
        script = Script.forCodePoints codePoints
        
      glyphs = string
            
    # Return early if there are no glyphs
    if glyphs.length is 0
      return new GlyphRun glyphs, []    
          
    if @font.GSUB or @font.GPOS
      shaper = Shapers.choose script
      features.push shaper.getGlobalFeatures(script)...
      
      # Map glyphs to GlyphInfo objects so data can be passed between
      # GSUB and GPOS without mutating the real (shared) Glyph objects.
      glyphs = for glyph, i in glyphs
        new GlyphInfo glyph.id, [glyph.codePoints...], features
        
      features.push shaper.assignFeatures(glyphs, script)...
      
    # Remove duplicate features
    featureMap = {}
    for feature in features
      featureMap[feature] = true
      
    features = Object.keys(featureMap)
      
    # Substitute and position the glyphs
    glyphs = @substitute glyphs, features, script
    positions = @position glyphs, features, script
    
    return new GlyphRun glyphs, positions
    
  substitute: (glyphs, features, script, language) ->
    # first, try the OpenType GSUB table
    if @font.GSUB
      @GSUBProcessor ?= new GSUBProcessor(@font, @font.GSUB)
      @GSUBProcessor.selectScript script, language
      @GSUBProcessor.applyFeatures(features, glyphs)

    # if not found, try AAT morx table
    else if @font.morx
      # AAT expects the glyphs to be reversed prior to morx processing,
      # so reverse the glyphs if the script is right-to-left.
      isRTL = Script.direction(script) is 'rtl'
      if isRTL
        glyphs.reverse()
      
      @morxProcessor ?= new AATMorxProcessor(@font)
      @morxProcessor.process(glyphs, AATFeatureMap.mapOTToAAT(features))
      
      # It is very unlikely, but possible for a font to have an AAT morx table
      # along with an OpenType GPOS table. If so, reverse the glyphs again for
      # GPOS, which expects glyphs to be in logical order.
      if isRTL and @font.GPOS
        glyphs.reverse()
      
    return glyphs
    
  class GlyphPosition
    constructor: (@xAdvance = 0, @yAdvance = 0, @xOffset = 0, @yOffset = 0) ->
      
  position: (glyphs, features, script, language) ->
    positions = []
    for glyph in glyphs
      positions.push new GlyphPosition @font.widthOfGlyph glyph.id
      
    if @font.GPOS
      @GPOSProcessor ?= new GPOSProcessor(@font, @font.GPOS)
      @GPOSProcessor.selectScript script, language
      @GPOSProcessor.applyFeatures(features, glyphs, positions)
      
      # Map the GlyphInfo objects back to real Glyphs
      for glyph, i in glyphs
        glyphs[i] = @font.getGlyph glyph.id, glyph.codePoints
        
      # Reverse the glyphs and positions if the script is right-to-left
      if Script.direction(script) is 'rtl'
        glyphs.reverse()
        positions.reverse()
      
    gposFeatures = @GPOSProcessor?.features or {}
        
    # if the mark and mkmk features are not supported by GPOS, or if
    # there is no GPOS table, use unicode properties to position marks.
    if 'mark' not of gposFeatures or 'mkmk' not of gposFeatures
      @unicodeLayoutEngine ?= new UnicodeLayoutEngine @font
      @unicodeLayoutEngine.positionGlyphs glyphs, positions
      
    # if kerning is not supported by GPOS, do kerning with the TrueType/AAT kern table
    if 'kern' not of gposFeatures and 'kern' in features and @font.kern
      @kernProcessor ?= new KernProcessor @font
      @kernProcessor.process glyphs, positions
          
    return positions
    
  getAvailableFeatures: (script, language) ->
    features = []
  
    if @font.GSUB
      @GSUBProcessor ?= new GSUBProcessor @font, @font.GSUB
      @GSUBProcessor.selectScript script, language
      features.push Object.keys(@GSUBProcessor.features)...
  
    if @font.GPOS
      @GPOSProcessor ?= new GPOSProcessor @font, @font.GPOS
      @GPOSProcessor.selectScript script, language
      features.push Object.keys(@GPOSProcessor.features)...
    
    if @font.morx
      @morxProcessor ?= new AATMorxProcessor @font
      aatFeatures = AATFeatureMap.mapAATToOT @morxProcessor.getSupportedFeatures()
      features.push aatFeatures...
    
    if @font.kern and (not @font.GPOS or 'kern' not of @GPOSProcessor.features)
      features.push 'kern'
    
    return features
    
module.exports = LayoutEngine
