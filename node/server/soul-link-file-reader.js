import fs from 'fs';
import path from 'path';
import EventEmitter from 'events';

import Pokedex from './pokemon/pokedex';

const SoulLinkFile = path.resolve(__dirname, '../public/soullinkdata.json');
class SoulLinkFileReader extends EventEmitter {
    constructor() {
        super();

        this._links = {};

        this.parseData = this.parseData.bind(this);
        this.parseData();
        this._filewatcher = new fs.watch(SoulLinkFile);
        this._filewatcher.on('change', this.parseData);
    }

    parseData() {
        if (!fs.existsSync(SoulLinkFile)) {
            fs.writeFileSync(SoulLinkFile, '{}');
            return;
        }

        let contents = "";
        try {
            contents = fs.readFileSync(SoulLinkFile);
            let next = JSON.parse(contents);
            let changed = false;

            for (let [pid, nextLink] of Object.entries(next)) {
                let n = Pokedex.Lower.indexOf(nextLink.linkedSpecies.toLowerCase());
                if (n === -1) {
                    console.error(`Invalid species name: ${nextLink.linkedSpecies}`);
                    return;
                }

                if (n === 0) {
                    next[pid].linkedSpecies = null;
                } else {
                    next[pid].linkedSpecies = n;
                }
            }

            for (let [pid, nextLink] of Object.entries(next)) {
                let old = this._links[pid];
                if (!old || old.linkedSpecies !== nextLink.linkedSpecies) {
                    changed = true;
                    break;
                }
            }

            this._links = next;
            if (changed) {
                this.emit('update', next);
            }
        } catch (e) {
            // pass
        }
    }

    addPokemon(pokemon) {
        this._links[pokemon.pid] = {
            yourPokemon: pokemon.nickname || pokemon.speciesName,
            linkedSpecies: ''
        };

        let fileLinks = Object.assign({}, this._links);
        for (let [pid, link] of Object.entries(fileLinks)) {
            if (link.linkedSpecies === null) {
                fileLinks[pid].linkedSpecies = '';
            } else if (link.linkedSpecies.constructor === Number) {
                fileLinks[pid].linkedSpecies = Pokedex[link.linkedSpecies];
            }
        }

        fs.writeFileSync(SoulLinkFile, JSON.stringify(fileLinks, null, 2));

        if (!this._filewatcher) {
            this._filewatcher = new fs.watch(SoulLinkFile);
            this._filewatcher.on('change', this.parseData);
        }
    }

    get Links() {
        return Object.assign({}, this._links);
    }
}

const fr = new SoulLinkFileReader();
export default fr;