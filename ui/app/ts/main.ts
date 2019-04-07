/// <reference path="greeter">

new Greeter().greet("Hello world");

Vue.component('linker', {
    props: ['name'],
    template: `
<div>
  <p>{{displayString}}</p>
  <input type="hidden" v-bind:name="name" v-bind:value="selectedUri">{{name}} Here is the linker</p>
  <input type="text" placeholder="Search" v-on:keyup="handleInput"></input>
</div>
`,
    data: function (): {selectedUri: string, displayString: string} {
        return {
            selectedUri: '',
            displayString: '',
        };
    },
    methods: {
        handleInput(event: any) {
            console.log(event.target.value);

            if (event.target.value.length > 10) {
                this.showPlaceholder("WOO", "RAN IT");
            }
        },
        showPlaceholder(label: string, uri: string) {
            this.displayString = label;
            this.selectedUri = uri;
        },
    }
});

