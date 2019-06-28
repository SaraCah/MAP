/// <amd-module name='main'/>

import Vue from "vue";

import 'confirmable-action';
import 'controlled-records';
import 'conversation';
import 'current-location-selector';
import 'file-issue-form';
import 'file-issue-requests-search';
import 'file-issues-search';
import 'file-uploader';
import 'linker';
import 'locations-search';
import 'notifications';
import 'representation-linker';
import 'select-with-other-option';
import 'service-quote';
import 'transfer-proposal-series';
import 'transfers-search';
import 'users-search';

declare var M: any; // Materialize on the window context

document.querySelectorAll('.vue-enabled').forEach(function(elt: Element) {
    /* tslint:disable:no-unused-expression */
    new Vue({el: elt});
});

M.ScrollSpy.init(document.querySelectorAll('.scrollspy'));
M.Dropdown.init(document.querySelectorAll('.menu-dropdown'), {constrainWidth: false, coverTrigger: false});
