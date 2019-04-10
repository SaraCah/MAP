import Vue from "vue";

import 'greeter';
import 'linker';

new Greeter().greet("Hello world");


document.querySelectorAll('.vue-widget').forEach(function(elt:Element) {
    new Vue({el: '#' + elt.id});
});
