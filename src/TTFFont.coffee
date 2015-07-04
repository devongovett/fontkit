r = require 'restructure'
Directory = require './tables/directory'
tables = require './tables'
CmapProcessor = require './CmapProcessor'
LayoutEngine = require './layout/LayoutEngine'
TTFGlyph = require './glyph/TTFGlyph'
CFFGlyph = require './glyph/CFFGlyph'
SBIXGlyph = require './glyph/SBIXGlyph'
COLRGlyph = require './glyph/COLRGlyph'
TTFSubset = require './subset/TTFSubset'
CFFSubset = require './subset/CFFSubset'
BBox = require './glyph/BBox'

class TTFFont
  get = require('./get')(this)
  constructor: (@stream) ->
    @_glyphs = {}
    @_decodeDirectory()
    
    # define properties for each table to lazily parse
    for tag, table of @directory.tables when tables[tag]
      Object.defineProperty this, tag,
        get: getTable.bind(this, table)
        
    return
        
  getTable = (table) ->
    key = '_' + table.tag
    unless key of this
      pos = @stream.pos
      @stream.pos = table.offset
      this[key] = @_decodeTable table
      @stream.pos = pos
      
    return this[key]
    
  _getTableStream: (tag) ->
    table = @directory.tables[tag]
    if table
      @stream.pos = table.offset
      return @stream
      
    return null
    
  _decodeDirectory: ->
    @directory = Directory.decode(@stream, _startOffset: 0)
    
  _decodeTable: (table) ->
    return tables[table.tag].decode(@stream, this, table.length)
        
  get 'postscriptName', ->
    name = @name.records.postscriptName
    lang = Object.keys(name)[0]
    return name[lang]
    
  get 'fullName', ->
    @name.records.fullName?.English
    
  get 'familyName', ->
    @name.records.fontFamily?.English
    
  get 'subfamilyName', ->
    @name.records.fontSubfamily?.English
    
  get 'copyright', ->
    @name.records.copyright?.English
    
  get 'version', ->
    @name.records.version?.English
    
  get 'ascent', ->
    @hhea.ascent
    
  get 'descent', ->
    @hhea.descent
    
  get 'lineGap', ->
    @hhea.lineGap
    
  get 'underlinePosition', ->
    @post.underlinePosition
    
  get 'underlineThickness', ->
    @post.underlineThickness
    
  get 'italicAngle', ->
    @post.italicAngle
    
  get 'capHeight', ->
    this['OS/2']?.capHeight or @ascent
    
  get 'xHeight', ->
    this['OS/2']?.xHeight or 0
    
  get 'numGlyphs', ->
    @maxp.numGlyphs
    
  get 'unitsPerEm', ->
    @head.unitsPerEm
    
  get 'bbox', ->
    @_bbox ?= Object.freeze new BBox @head.xMin, @head.yMin, @head.xMax, @head.yMax
    
  get 'characterSet', ->
    @_cmapProcessor ?= new CmapProcessor @cmap
    return @_cmapProcessor.getCharacterSet()
        
  hasGlyphForCodePoint: (codePoint) ->
    @_cmapProcessor ?= new CmapProcessor @cmap
    return !!@_cmapProcessor.lookup codePoint
            
  glyphForCodePoint: (codePoint) ->
    @_cmapProcessor ?= new CmapProcessor @cmap
    return @getGlyph @_cmapProcessor.lookup(codePoint), [codePoint]
        
  codePointAt = (str, idx = 0) ->
    code = str.charCodeAt(idx)
    next = str.charCodeAt(idx + 1)
    
    # If a surrogate pair
    if 0xd800 <= code <= 0xdbff and 0xdc00 <= next <= 0xdfff
      return ((code - 0xd800) * 0x400) + (next - 0xdc00) + 0x10000
      
    return code
                
  glyphsForString: (string) ->
    # Map character codes to glyph ids
    glyphs = []
    for i in [0...string.length] by 1
      # check for already processed low surrogates
      continue if 0xdc00 <= string.charCodeAt(i) <= 0xdfff
      
      # get the glyph
      glyphs.push @glyphForCodePoint codePointAt(string, i)
      
    return glyphs
    
  layout: (string, userFeatures, script, language) ->
    @_layoutEngine ?= new LayoutEngine this
    return @_layoutEngine.layout string, userFeatures, script, language
    
  get 'availableFeatures', ->
    @_layoutEngine ?= new LayoutEngine this
    return @_layoutEngine.getAvailableFeatures()
    
  _getMetrics: (table, glyph) ->
    if glyph < table.metrics.length
      return table.metrics[glyph]
      
    return table.metrics[table.metrics.length - 1]
    
  widthOfGlyph: (glyph) ->
    return @_getMetrics(@hmtx, glyph).advanceWidth
        
  widthOfString: (string, features, script, language) ->
    @_layoutEngine ?= new LayoutEngine this
    return @_layoutEngine.layout(string, features, script, language).advanceWidth
    
  _getBaseGlyph: (glyph, characters = []) ->
    unless @_glyphs[glyph]
      if @directory.tables.glyf?
        @_glyphs[glyph] = new TTFGlyph glyph, characters, this
      
      else if @directory.tables['CFF ']?
        @_glyphs[glyph] = new CFFGlyph glyph, characters, this
    
    return @_glyphs[glyph] or null
    
  getGlyph: (glyph, characters = []) ->
    unless @_glyphs[glyph]
      if @directory.tables.sbix?
        @_glyphs[glyph] = new SBIXGlyph glyph, characters, this
        
      else if @directory.tables.COLR? and @directory.tables.CPAL?
        @_glyphs[glyph] = new COLRGlyph glyph, characters, this
        
      else
        @_getBaseGlyph glyph, characters
    
    return @_glyphs[glyph] or null
    
  createSubset: ->
    if @directory.tables['CFF ']?
      return new CFFSubset this
      
    return new TTFSubset this
        
module.exports = TTFFont
