export default class Utils {
    public static filter<T>(array: T[], predicate: (item: T) => boolean): T[] {
        const result: T[] = [];

        array.forEach((item: T) => {
            if (predicate(item)) {
                result.push(item);
            }
        });

        return result;
    }

    public static find<T>(array: T[], predicate: (item: T) => boolean): T | null {
        for (const item of array) {
            if (predicate(item)) {
                return item;
            }
        }

        return null;
    }
}
