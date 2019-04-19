import Vue from "vue";

import 'linker';
import 'current-location-selector';

document.querySelectorAll('.vue-enabled').forEach(function(elt:Element) {
    new Vue({el: elt});
});
