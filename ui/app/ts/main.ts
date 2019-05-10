/// <amd-module name='main'/>

import Vue from "vue";

import 'confirmable-action';
import 'conversation';
import 'current-location-selector';
import 'file-uploader';
import 'linker';
import 'transfer-proposal-series';

declare var M: any; // Materialize on the window context

document.querySelectorAll('.vue-enabled').forEach(function(elt: Element) {
    /* tslint:disable:no-unused-expression */
    new Vue({el: elt});
});

M.ScrollSpy.init(document.querySelectorAll('.scrollspy'));

