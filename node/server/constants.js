import './extensions';
import { Img } from './image-format';

let SupportedImageFormats = [
    Img('jpg', 'jpeg', ['jpg', 'jpeg']),
    Img('png'),
    Img('apng'),
    Img('gif'),
    Img('svg', 'svg+xml'),
    Img('bmp'),
    Img('ico', 'x-icon'),
];

SupportedImageFormats.validExtensions = SupportedImageFormats.map(f => f.searchStrings).flatten();

// 201 is Unown who has 26 forms: 201a - 201z
// s post-fix denotes shiny
const ImageRegex = new RegExp(`(201-?[a-z]|\\d+)(s?)\\.(${SupportedImageFormats.validExtensions.join('|')})$`, 'i');

const ConfigFile = process.env.CONFIG_JSON || 'config.json';
export { SupportedImageFormats, ImageRegex, ConfigFile };