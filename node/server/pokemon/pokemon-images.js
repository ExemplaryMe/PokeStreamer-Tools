import path from 'path';
import fs from 'fs';
import EventEmitter from 'events';
import Config from '../config';
import { Image, Paths } from '../constants';

const {
    ImageRegex, 
    ShinyImageRegex,
    EggImageRegex,
    SupportedImageFormats
} = Image;

const basicImageDirs = {
    base: '.',
    female: 'female',
    shiny: 'shiny',
    shinyFemale: 'shiny/female'
};

class PokemonImages extends EventEmitter {
    constructor() {
        super();

        this._images = {};
        this._gettingFormImages = false;

        this._initPokemonImages();

        Config.on('update', e => {
            if (e.prev.pokemonImagesPath !== e.next.pokemonImagesPath ||
                e.prev.emptySlotImagePath !== e.next.emptySlotImagePath) {
                console.log('Pokemon image paths in config changed.  Reloading all images.');
                this._initPokemonImages();
            }
        });
    }

    get(species) {
        return this._images[species];
    }

    _initPokemonImages() {
        this._images = {};
        this._gettingFormImages = false;
    
        if (!Config.Current.emptySlotImagePath) {
            console.warn('No specified empty slot image.  Skipping.');
            this._images[-1] = new PokemonImage();
        } else {
            this._setEmptySlotImage(path.resolve(Paths.NodeRoot, Config.Current.emptySlotImagePath));
        }
        
        let basePath = path.resolve(Paths.NodeRoot, Config.Current.pokemonImagesPath),
            formsPath = path.resolve(basePath, 'forms');
        
        if (!fs.existsSync(basePath)) {
            throw new Error(`Specified pokemonImagePath '${basePath}' in config does not exist.`);
        }
        
        this._loadImageDir(basePath);
        
        if (!fs.existsSync(formsPath)) {
            console.warn(`No additional forms directory found at '${path.resolve(formsPath)}'.`);
            return;
        }
        
        this._gettingFormImages = true;
        for (let dir of fs.readdirSync(formsPath)) {
            let dirPath = path.resolve(formsPath, dir);
            if (!fs.lstatSync(dirPath).isDirectory()) {
                continue;
            }
            
            this._loadImageDir(dirPath);
        }
    }

    _getImgSrcString(filePath, fileType) {
        let data = Buffer.from(fs.readFileSync(filePath)).toString('base64');
        return `data:image/${fileType};base64, ${data}`;
    }

    _loadImages(variant, dir) {
        let basePath = path.resolve(Paths.NodeRoot, Config.Current.pokemonImagesPath),
            formsPath = path.resolve(basePath, 'forms');

        if (!fs.existsSync(dir)) {
            // search for shiny/female variants for all normal forms
            // don't search for shiny/female variants of egg
            // otherwise make sure there is at least shiny variant for each alternate form
            if (!this._gettingFormImages || (variant === 'shiny' && path.relative(formsPath, dir).search('egg') === -1)) {
                console.warn(`Warning: Image directory '${dir}' does not exist.  Skipping.`);
            }
    
            return;
        }
        
        let imagesFound = 0;
        
        for (let file of fs.readdirSync(dir)) {
            let m, id, alternateForm, fileType,
                filePath = path.resolve(dir, file),
                shiny = variant.search('shiny') !== -1;
            
            if (!fs.lstatSync(filePath).isFile()) {
                // skip directories
                continue;
            }
            
            if (shiny) {
                m = ShinyImageRegex.exec(file);
            } else {
                m = ImageRegex.exec(file);
            }
            
            id = m && m[1];
            alternateForm = m && m[2];
            fileType = m && m[3];
            
            if (id) {
                if (id === '0') {
                    // attempting to add an egg that is not an egg image
                    continue;
                }

                if (!this._images[id]) {
                    this._images[id] = new PokemonImage();
                }
                
                if (!alternateForm) {
                    this._images[id][variant] = this._getImgSrcString(filePath, fileType);
                } else {
                    if (!this._images[id].forms[alternateForm]) {
                        this._images[id].forms[alternateForm] = new PokemonImage();
                    }    
                    
                    this._images[id].forms[alternateForm][variant] = this._getImgSrcString(filePath, fileType);                
                }
                
                imagesFound++;
            } else if ((m = EggImageRegex.exec(file)) !== null) {
                if (this._images[0]) {
                    // already have an egg
                    continue;
                }

                fileType = m[3];
                
                this._images[0] = new PokemonImage();
                this._images[0]['base'] = this._getImgSrcString(filePath, fileType);
            }
        }
        
        console.log(`Found ${imagesFound} ${variant} images in ${fs.realpathSync(dir)}`);
    }

    _setEmptySlotImage(filePath) {
        if (!fs.existsSync(filePath)) {
            console.warn(`emptySlot image '${filePath}' does not exist.  Skipping.`);
            return;
        }
        
        let m = /\.(png|gif|jpg|jpeg|bmp)/i.exec(filePath);
        if (!m) {
            console.warn(`emptySlot image '${filePath}' has unrecognized image type.  Skipping.  Valid image extensions: png, gif, jpg, jepg, and bmp`);
            return;
        }
        
        this._images[-1] = new PokemonImage();
        this._images[-1].base = this._getImgSrcString(filePath, m[1]);
    }

    _loadImageDir(dirPath) {
        for (let [variant, varientPath] of Object.entries(basicImageDirs)) {
            this._loadImages(variant, path.resolve(dirPath, varientPath));
        }
    }
}

class PokemonImage {
    constructor() {
        this.base = null;
        this.female = null;
        this.shiny = null;
        this.shinyFemale = null;
        this.forms = {};
    }
    
    getImage(female, shiny, form, egg) {
        if (egg) {
            return pokemonImages.get(0).base;
        }

        if (form && this.forms[form]) {
            return this.forms[form].getImage(female, shiny) || this.base;
        }
        
        if (female && shiny) {
            return this.shinyFemale || this.shiny || this.female || this.base;
        } else if (female) {
            return this.female || this.base;
        } else if (shiny) {
            return this.shiny || this.base;
        } else {
            return this.base;
        }
    }
}

const pokemonImages = new PokemonImages();
export default pokemonImages;