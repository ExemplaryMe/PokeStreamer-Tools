import fs from 'fs';
import path from 'path';
import json5 from 'json5';
import EventEmitter from 'events';
import { ConfigFile } from './constants';

class Config extends EventEmitter {
    constructor() {
        super();

        this._readConfig();
        fs.watch(path.resolve(ConfigFile), this._readConfig.bind(this));
    }

    _readConfig() {
        let next;
        try
        {
            next = json5.parse(fs.readFileSync(path.resolve(ConfigFile)));
        } catch (e) {
            // an error is thrown if config.json is empty, which happens immediately after saving the file
            return;
        }

        // sloppy but it doesn't really matter for our purposes if we load too many times
        if (this._current && JSON.stringify(this._current) === JSON.stringify(next)) {
            return;
        }

        let prev = this._current;
        this._current = next;
        this.emit('update', { prev: prev, next: this._current });
    }

    get Current() { return Object.assign({}, this._current); }
}

const config = new Config();
export default config;