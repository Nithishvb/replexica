import { ILoader, ILoaderDefinition } from "./_types";

export function composeLoaders(...loaders: ILoader<any, any>[]): ILoader<any, any> {
  return {
    setDefaultLocale(locale: string) {
      for (const loader of loaders) {
        loader.setDefaultLocale?.(locale);
      }
      return this;
    },
    pull: async (locale, input) => {
      let result: any = input;
      for (let i = 0; i < loaders.length; i++) {
        result = await loaders[i].pull(locale, result);
      }
      return result;
    },
    push: async (locale, data) => {
      let result: any = data;
      for (let i = loaders.length - 1; i >= 0; i--) {
        result = await loaders[i].push(locale, result);
      }
      return result;
    },
    // onStart: async () => {
    //   for (let i = 0; i < loaders.length; i++) {
    //     await loaders[i].onStart?.();
    //   }
    // },
    // onProgress: async (current, total) => {
    //   for (let i = 0; i < loaders.length; i++) {
    //     await loaders[i].onProgress?.(current, total);
    //   }
    // },
    // onEnd: async () => {
    //   for (let i = loaders.length - 1; i >= 0; i--) {
    //     await loaders[i].onEnd?.();
    //   }
    // },
  };
}

export function createLoader<I, O>(lDefinition: ILoaderDefinition<I, O>): ILoader<I, O> {
  const state = {
    defaultLocale: undefined as string | undefined,
    originalInput: undefined as I | undefined | null,
  };
  return {
    setDefaultLocale(locale) {
      if (state.defaultLocale) { throw new Error('Default locale already set'); }
      state.defaultLocale = locale;
      return this;
    },
    async pull(locale, input) {
      if (!state.defaultLocale) {
        throw new Error('Default locale not set');
      }
      if (state.originalInput === undefined && locale !== state.defaultLocale) {
        throw new Error('The first pull must be for the default locale');
      }
      if (locale === state.defaultLocale) {
        state.originalInput = input || null;
      }

      return lDefinition.pull(locale, input);
    },
    async push(locale, data) {
      if (!state.defaultLocale) {
        throw new Error('Default locale not set');
      }
      if (state.originalInput === undefined) {
        throw new Error('Cannot push data without pulling first');
      }

      return lDefinition.push(locale, data, state.originalInput);
    },
    // async onStart() {
    //   await lDefinition.onStart?.();
    // },
    // async onProgress(current, total) {
    //   await lDefinition.onProgress?.(current, total);
    // },
    // async onEnd() {
    //   await lDefinition.onEnd?.();
    // },
  } as ILoader<I, O>;
}
