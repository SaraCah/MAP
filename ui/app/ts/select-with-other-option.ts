/// <amd-module name='select-with-other-option'/>


import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);
import Utils from "./utils";

interface SelectOption {
    value: string;
    label: string;
}

Vue.component('select-with-other-option', {
    template: `
<div>
    <label :for="input_id">{{input_label}}</label>
    <select id="request_type" :name="input_name" class="browser-default" v-model="selected_value">
        <option v-for="option in options" :value="option.value">{{option.label}}</option>
        <option value="OTHER">Other</option>
    </select>
    <template v-if="selected_value === 'OTHER'">
        <input type="text" :name="input_name" v-model="otherText" :placeholder="'Please enter your ' + input_label + '...'"/>
    </template>
</div>
`,
    data: function(): {
            otherText:string,
            options: Array<SelectOption>,
            selected_value: string,
        } {

        let parsedOptions:Array<SelectOption> = JSON.parse(this.options_json);

        let selectedOption:SelectOption|null = Utils.find(parsedOptions, (opt:SelectOption) => {
            return opt.value === this.current_selection;
        });

        let selected_value = (selectedOption === null) ? 'OTHER' : selectedOption.value;
        let other_text = (selectedOption === null) ? this.current_selection : '';

        return {
            otherText: other_text,
            options: parsedOptions,
            selected_value: selected_value,
        };
    },
    props: ['input_id', 'input_name', 'input_label', 'options_json', 'current_selection'],
    mounted: function() {

    } 
});
