/// <amd-module name='main'/>

import Vue from "vue";

import 'ajax-form';
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
import 'manage-agency';
import 'manage-current-user';
import 'manage-system';
import 'notifications';
import 'representation-linker';
import 'search-requests-search';
import 'select-with-other-option';
import 'service-quote';
import 'transfer-proposal-series';
import 'transfers-search';
import 'user-for-location-picker';
import 'users-search';

declare var M: any; // Materialize on the window context

declare global {
    interface Window { MAP: any; }
}

window.MAP = {
    // Called when the page first loads, plus any time we load AJAX content that
    // might contain components that need to be initialised.
    init: function () {
        document.querySelectorAll('.vue-enabled').forEach(function(elt: Element) {
            /* tslint:disable:no-unused-expression */
            if (!elt.classList.contains('vue-map-initialised')) {
                elt.classList.add('vue-map-initialised');
                new Vue({el: elt});
            }
        });

        M.ScrollSpy.init(document.querySelectorAll('.scrollspy'));
        M.Dropdown.init(document.querySelectorAll('.menu-dropdown'), {constrainWidth: false, coverTrigger: false});
        M.Tooltip.init(document.querySelectorAll('.tooltipped'));


        document.querySelectorAll('.tabs').forEach(function (elt: Element) {
            M.Tabs.init(elt, {});
        });
    },
};

window.MAP.init();
