/// <reference path="greeter">

new Greeter().greet();

const Component = Vue.extend({
    el: '#vuething',
    template: '<p>{{firstName}} {{lastName}} aka {{alias}}</p>',
    data: function (): { firstName: string, lastName: string, alias: string } {
        return {
            firstName: 'MARK',
            lastName: 'TRIGGS',
            alias: 'WHATEVER'
        }
    }
})

new Component();
