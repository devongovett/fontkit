Path = require './Path'
unicode = require 'unicode-properties'

class Glyph
  get = require('../get')(this)
  constructor: (@id, @codePoints, @_font) ->
    # TODO: get this info from GDEF if available
    @isMark = @codePoints.every unicode.isMark
    @isLigature = @codePoints.length > 1
      
  _getPath: ->
    return new Path
      
  _getCBox: ->
    @path.cbox
    
  _getBBox: ->
    @path.bbox
    
  getMetrics = (table, gid) ->
    if gid < table.metrics.length
      return table.metrics[gid]
      
    res = 
      advance: table.metrics[table.metrics.length - 1].advance
      bearing: table.bearings[gid - table.metrics.length]
      
    return res
    
  _getMetrics: (cbox = @cbox) ->
    return @_metrics if @_metrics
      
    {advance:advanceWidth, bearing:leftBearing} = getMetrics @_font.hmtx, @id
    
    # For vertical metrics, use vmtx if available, or fall back to global data from OS/2 or hhea
    if @_font.vmtx
      {advance:advanceHeight, bearing:topBearing} = getMetrics @_font.vmtx, @id
      
    else if (os2 = @_font['OS/2']) and os2.version > 0
      advanceHeight = Math.abs os2.typoAscender - os2.typoDescender
      topBearing = os2.typoAscender - cbox.maxY
    
    else
      hhea = @_font.hhea
      advanceHeight = Math.abs hhea.ascent - hhea.descent
      topBearing = hhea.ascent - cbox.maxY
    
    @_metrics = { advanceWidth, advanceHeight, leftBearing, topBearing }
      
  get 'cbox', ->
    @_cbox ?= @_getCBox()
      
  get 'bbox', ->
    @_bbox ?= @_getBBox()
    
  get 'path', ->
    # Cache the path so we only decode it once
    # Decoding is actually performed by subclasses
    @_path ?= @_getPath()
    
  get 'advanceWidth', ->
    @_advanceWidth ?= @_getMetrics().advanceWidth
    
  get 'advanceHeight', ->
    @_advanceHeight ?= @_getMetrics().advanceHeight
    
  get 'ligatureCaretPositions', ->
    
  render: (ctx, size) ->
    ctx.save()
    ctx.scale size / @_font.unitsPerEm

    fn = @path.toFunction()
    fn(ctx)
    ctx.fill()
    
    ctx.restore()
    
module.exports = Glyph
