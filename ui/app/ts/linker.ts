import Vue from "vue";
import VueResource from "vue-resource";
Vue.use(VueResource);


interface agency {
    id: number,
    label: string,
}


Vue.component('agency-linker', {
    template: `
<div>
<input v-on:keyup="handleInput" type="text"></input>
<ul>
<li v-for="agency in matches">
  {{ agency.label }}
</li>
</ul>
</div>
`,
    data: function (): { selectedAgencyId: number | null, displayString: string, matches: agency[] } {
        return {
            selectedAgencyId: null,
            displayString: '',
            matches: [],
        }
    },
    methods: {
        handleInput(event: any) {
            if (event.target.value.length > 3) {
                this.$http.get('/search/agencies', {
                    method: 'GET',
                    params: {
                        q: event.target.value,
                    }
                }).then((response: any) => {
                    return response.json();
                }, () => {
                    console.log("FAIL");
                    this.matches = [];
                }).then((json: any) => {
                    this.matches = json;
                });
            }
        },

    }
});



// class AgencyLinker {
// 
//     constructor($input) {
//         this.$input = $input;
//         this.$hiddenInputId = $input.siblings('.morty-relationship-object-id');
//         this.$hiddenInputRepository = this.$input.siblings('morty-relationship-object-repository');
// 
//         this.$autocomplete = $('<ul id="ac" class="autocomplete-content dropdown-content"'
//                                + 'style="position:absolute"></ul>');
//         this.$inputDiv = this.$input.closest('.input-field');
// 
//         this.request = undefined;
//         this.runningRequest = false;
//         this.timeout = undefined;
//         this.liSelected = undefined;
//         this.next = undefined;
// 
//         this.types = [];
// 
//         this.init();
//     }
// 
//     init() {
//         var self = this;
// 
//         if (self.$inputDiv.length) {
//             self.$inputDiv.append(self.$autocomplete); // Set ul in body
//         } else {
//             self.$input.after(self.$autocomplete);
//         }
// 
// 
//         self.$autocomplete.on('click', 'li', function (event) {
//             event.preventDefault();
//             event.stopPropagation();
// 
//             self.$input.val('');
//             self.$hiddenInputId.val('');
//             self.$hiddenInputRepository.val('');
//             self.$input.siblings('.prefix').remove();
// 
//             if ($(this).data('id')) {
//                 self.$input.val($(this).data('display_string'));
//                 self.$hiddenInputId.val($(this).data('id'));
//                 self.$hiddenInputRepository.val($(this).data('repository'));
// 
//                 if ($(this).data('icon')) {
//                     var $icon = $($(this).data('icon'));
//                     $icon.addClass('prefix');
//                     self.$input.before($icon);
//                 }
//             }
// 
//             self.$autocomplete.empty();
//             self.$input.focus();
//         });
// 
//         self.$input.on('keydown', function (e) {
//             if (e.which === 13) { // select element with Enter
//                 e.preventDefault();
//                 e.stopPropagation();
// 
//                 self.liSelected[0].click();
//                 return false;
//             }
//             return true;
//         });
// 
//         self.$input.on('keyup', function (e) {
// 
//             if (self.timeout) { // comment to remove timeout
//                 clearTimeout(self.timeout);
//             }
// 
//             if (self.runningRequest) {
//                 self.request.abort();  // stop requests that are already sent
//             }
// 
//             if (e.which === 13) { // select element with Enter
//                 self.liSelected[0].click();
//                 return false;
//             }
// 
//             // scroll ul with arrow keys
//             if (e.which === 40) {   // down arrow
//                 if (self.liSelected) {
//                     self.liSelected.removeClass('selected');
//                     self.next = self.liSelected.next();
//                     if (self.next.length > 0) {
//                         self.liSelected = self.next.addClass('selected');
//                     } else {
//                         self.liSelected = self.$autocomplete.find('li').eq(0).addClass('selected');
//                     }
//                 } else {
//                     self.liSelected = self.$autocomplete.find('li').eq(0).addClass('selected');
//                 }
//                 return; // stop new AJAX call
//             } else if (e.which === 38) { // up arrow
//                 if (self.liSelected) {
//                     self.liSelected.removeClass('selected');
//                     self.next = self.liSelected.prev();
//                     if (self.next.length > 0) {
//                         self.liSelected = self.next.addClass('selected');
//                     } else {
//                         self.liSelected = self.$autocomplete.find('li').last().addClass('selected');
//                     }
//                 } else {
//                     self.liSelected = self.$autocomplete.find('li').last().addClass('selected');
//                 }
//                 return;
//             }
// 
//             // escape these keys
//             if (e.which === 9 ||        // tab
//                 e.which === 16 ||       // shift
//                 e.which === 17 ||       // ctrl
//                 e.which === 18 ||       // alt
//                 e.which === 20 ||       // caps lock
//                 e.which === 35 ||       // end
//                 e.which === 36 ||       // home
//                 e.which === 37 ||       // left arrow
//                 e.which === 39) {       // right arrow
//                 return;
//             } else if (e.which === 27) { // Esc. Close ul
//                 self.$autocomplete.empty();
//                 return;
//             }
// 
//             var val = self.$input.val().toLowerCase();
//             self.$autocomplete.empty();
// 
//             if (val.length >= 1) {
//                 self.timeout = setTimeout(function () {
//                     self.runningRequest = true;
//                     self.request = $.ajax({
//                         type: 'GET',
//                         url: '/search/typeahead',
//                         data: {
//                             q: val,
//                             type: self.types,
//                         },
//                         success: function (data) {
//                             if (data.length > 0) {
//                                 var appendList = [];
//                                 data.forEach(function(result) {
//                                     var $li = $('<li>');
//                                     var $span = $('<span>').html(self.highlight(result.display_string, val));
//                                     $span.prepend($(result.icon).addClass('left'));
//                                     $li.append($span);
//                                     $li.data('id', result.id);
//                                     $li.data('display_string', result.display_string);
//                                     $li.data('icon', result.icon);
//                                     $li.data('repository', result.repository);
//                                     appendList.push($li);
//                                 });
//                                 self.$autocomplete.append(appendList);   // finally appending everything
//                             }else{
//                                 self.$autocomplete.append($('<li><span>No matches</span></li>'));
//                             }
//                         },
//                         complete: function () {
//                             self.runningRequest = false;
//                         }
//                     });
//                 }, 250);
//             }
//         });
// 
//         $(document).click(function (event) { // close ul if clicked outside
//             if (!$(event.target).closest(self.$autocomplete).length) {
//                 self.$autocomplete.empty();
//             }
//         });
//     }
// 
//     highlight(string, match) {
//         var matchStart = string.toLowerCase().indexOf("" + match.toLowerCase() + ""),
//         matchEnd = matchStart + match.length - 1,
//         beforeMatch = string.slice(0, matchStart),
//         matchText = string.slice(matchStart, matchEnd + 1),
//         afterMatch = string.slice(matchEnd + 1);
//         string = "<span>" + beforeMatch + "<span class='highlight'>" +
//             matchText + "</span>" + afterMatch + "</span>";
//         return string;
//     }
// 
//     reset_for_types: (types) {
//         this.$input.val('');
//         this.$hiddenInputId.val('');
//         this.$hiddenInputRepository.val('');
//         
//         this.$input.siblings('.prefix').remove();
//         this.types = types;
//     }
// 
//     disable() {
//         this.$input.prop('disabled', true);
//         this.$hiddenInputId.prop('disabled', true);
//         this.$hiddenInputRepository.prop('disabled', true);
//     }
// 
//     enable() {
//         this.$input.prop('disabled', false);
//         this.$hiddenInputId.prop('disabled', false);
//         this.$hiddenInputRepository.prop('disabled', false);
//     }
// }
