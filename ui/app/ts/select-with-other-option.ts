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
    <select id="request_type" :name="input_name" class="browser-default" v-model="selectedValue" :disabled="readonly">
        <option v-for="option in options" :value="option.value">{{option.label}}</option>
        <option value="OTHER">Other</option>
    </select>
    <template v-if="selectedValue === 'OTHER'">
        <input type="text" :name="input_name" v-model="otherText" :placeholder="'Please enter your ' + input_label + '...'"  :disabled="readonly" />
    </template>
</div>
`,
    data: function(): {
            otherText: string,
            options: SelectOption[],
            selectedValue: string,
            readonly: boolean,
        } {

        const parsedOptions: SelectOption[] = JSON.parse(this.options_json);

        const selectedOption: SelectOption|null = Utils.find(parsedOptions, (opt: SelectOption) => {
            return opt.value === this.current_selection;
        });

        const selectedValue = (selectedOption === null) ? 'OTHER' : selectedOption.value;
        const otherText = (selectedOption === null) ? this.current_selection : '';

        return {
            otherText: otherText,
            options: parsedOptions,
            selectedValue: selectedValue,
            readonly: this.is_readonly === 'true',
        };
    },
    props: ['input_id', 'input_name', 'input_label', 'options_json', 'current_selection', 'is_readonly'],
});
