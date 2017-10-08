import AbstractFontKit from './AbstractFontKit.js'

export default class FontKit extends AbstractFontKit {
  open(url, postscriptName, callback){
    let promise = fetch(url).then(result=>{
      if(!result.ok){
        throw result;
      } else {
        return result.arrayBuffer();
      }
    }).then(arrayBuffer => {
      return this.create(arrayBuffer, postscriptName);
    }).then(font=>{
      if(!callback){
        return font;
      } else {
        return callback(null, font);
      }
    }).catch(error=>{
      if(callback){
        callback(error);
      }

      throw error;
    });

    return promise;
  }
}