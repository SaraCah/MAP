import Vue from "vue";

import 'greeter';
import 'linker';
import 'current-location-selector';

new Greeter().greet("Hello world");

document.querySelectorAll('.vue-enabled').forEach(function(elt:Element) {
    new Vue({el: elt});
});
