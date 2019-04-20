/// <amd-module name='main'/>

import Vue from "vue";

import 'current-location-selector';
import 'linker';

document.querySelectorAll('.vue-enabled').forEach(function(elt: Element) {
    /* tslint:disable:no-unused-expression */
    new Vue({el: elt});
});
