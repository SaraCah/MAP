/// <amd-module name='main'/>

import Vue from "vue";

import 'confirmable-action';
import 'conversation';
import 'current-location-selector';
import 'file-issue-form';
import 'file-uploader';
import 'linker';
import 'representation-linker';
import 'select-with-other-option';
import 'transfer-proposal-series';
import 'file-issue-notifications';
import 'controlled-records';

declare var M: any; // Materialize on the window context

document.querySelectorAll('.vue-enabled').forEach(function(elt: Element) {
    /* tslint:disable:no-unused-expression */
    new Vue({el: elt});
});

M.ScrollSpy.init(document.querySelectorAll('.scrollspy'));

