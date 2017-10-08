import r from 'restructure';
import TTFFont from './TTFFont';
import WOFFFont from './WOFFFont';
import WOFF2Font from './WOFF2Font';
import TrueTypeCollection from './TrueTypeCollection';
import DFont from './DFont';

class AbstractFontKit {

  constructor(formats = [], logErrors = false){
    this.logErrors = logErrors;
    this.formats = formats;
    this.registerFormat(TTFFont);
    this.registerFormat(WOFFFont);
    this.registerFormat(WOFF2Font);
    this.registerFormat(TrueTypeCollection);
    this.registerFormat(DFont);
  }

  registerFormat(format){
    this.formats.push(format);
  }

  create(buffer, postScriptName){
    let font = null;

    //Browser buffer is incompatible with Node's API
    if(buffer instanceof ArrayBuffer){
      buffer = Buffer.from(buffer);
    }

    let format = this.formats.find(format => {
      return format.probe(buffer);
    });

    if(format){
      const stream = new r.DecodeStream(buffer);
      font = new format(stream);

      if(postScriptName){
        font = font.getFont(postScriptName);
      }

    }

    if(font === null){
      throw new Error('Unknown font format');
    } else {
      return font;
    }
  }

}

export default AbstractFontKit;
