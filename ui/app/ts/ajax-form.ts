/// <amd-module name='ajax-form'/>

export default class AjaxForm {
    private successCallback: () => void;

    private rootElement: HTMLElement;
    private formElements: NodeListOf<HTMLFormElement>;

    constructor(rootElement: HTMLElement, successCallback: () => void) {
        window.MAP.init();

        this.successCallback = successCallback;

        this.rootElement = rootElement;
        this.formElements = rootElement.querySelectorAll('form');
    }

    public setup() {
        for (const form of this.formElements) {
            // Can be fired to indicate success without needing a form submission
            //
            // Call like: formElt.dispatchEvent(new Event('ajax-success'));
            //
            form.addEventListener('ajax-success', (e) => {
                e.preventDefault();
                e.stopPropagation();
                this.successCallback();
                return false;
            });

            form.addEventListener('submit', (e) => {
                fetch(form.action, {
                    method: form.method,
                    body: new FormData(form),
                }).then((response) => {
                    if (response.status === 202) {
                        // Create/update was accepted
                        this.successCallback();
                        return Promise.resolve('');
                    } else {
                        // Update went wrong.  Should have an error response.
                        return response.text();
                    }
                }).then((body) => {
                    this.rootElement.innerHTML = body;

                    new AjaxForm(this.rootElement, this.successCallback).setup();
                });

                e.preventDefault();
                return false;
            });
        }
    }
}
