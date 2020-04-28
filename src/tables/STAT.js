import r from 'restructure';


let AxisRecord = new r.Struct({
  axisTag:      new r.String(4),    // e.g. 'ital', 'wght'
  axisNameID:   r.uint16,
  axisOrdering: r.uint16,
})

let AxisValue = new r.VersionedStruct( r.uint16, {
  header: {
    axisIndex:      r.uint16,
    flags:          r.uint16,
    valueNameID:    r.uint16,
  },
  1: {
    value:          r.fixed32be,
  },
  2: {
    nominalValue:   r.fixed32be,
    rangeMinValue:  r.fixed32be,
    rangeMaxValue:  r.fixed32be,
  },
  3: {
    value:          r.fixed32be,
    linkedValue:    r.fixed32be,
  },
})

let AxisValueArray = new r.Struct( {
  axisValues: new r.Array(new r.Pointer(r.uint16, AxisValue),
                                        parent => parent.parent.axisValueCount),
})


export default new r.VersionedStruct( r.uint32, {
  header: {
    designAxisSize:       r.uint16,
    designAxisCount:      r.uint16,
    offsetToDesignAxes:   new r.Pointer(r.uint32,
                                  new r.Array(AxisRecord,
                                              'designAxisCount')),
    axisValueCount:       r.uint16,
    offsetToAxisValueOffsets: new r.Pointer(r.uint32, AxisValueArray),
  },
  // Obsoleted version 1.0 ?
  0x00010000: {
  },
  // Apparently version 1.1 added 'ElidedFallbackNameID'
  0x00010001: {
    elidedFallbackNameID: r.uint16,
  },
})

