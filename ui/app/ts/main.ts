/// <amd-module name='main'/>

import Vue from "vue";

import 'current-location-selector';
import 'linker';
import 'file-uploader';
import 'transfer-proposal-series';

document.querySelectorAll('.vue-enabled').forEach(function(elt: Element) {
    /* tslint:disable:no-unused-expression */
    new Vue({el: elt});
});
