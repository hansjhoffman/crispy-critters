import * as Sentry from "@sentry/browser";
import * as E from "fp-ts/Either";
import { pipe } from "fp-ts/function";
import * as IO from "fp-ts/IO";
import * as J from "fp-ts/Json";
import PubNub from "pubnub";
import { match } from "ts-pattern";

import { Elm } from "./Main.elm";
import "./globals.css";
import "./devs";

const app = Elm.Main.init({
  node: document.querySelector<HTMLDivElement>("#root"),
  flags: null,
});

const isProd = (): boolean => import.meta.env.PROD;

Sentry.init({
  dsn: "https://b993e394b2e3581b7d53189f404260db@o4505920220692480.ingest.sentry.io/4506101001551872",
  debug: !isProd(),
  integrations: [new Sentry.BrowserTracing(), new Sentry.Replay()],

  // Set tracesSampleRate to 1.0 to capture 100%
  // of transactions for performance monitoring.
  // We recommend adjusting this value in production
  tracesSampleRate: 1.0,

  // Set `tracePropagationTargets` to control for which URLs distributed tracing should be enabled
  tracePropagationTargets: ["localhost", "https://venerable-fenglisu-8c0f2c.netlify.app"],

  // Capture Replay for 10% of all sessions,
  // plus for 100% of sessions with an error
  replaysSessionSampleRate: 0.1,
  replaysOnErrorSampleRate: 1.0,
});

const css: string = "color: #ffffff; background-color: #4c48ef; padding: 4px;";

export const prettyPrint = (
  level: "info" | "warn" | "error",
  title: string,
  messages: ReadonlyArray<string>,
): void => {
  console.group(`%c[ffx-event-listener] ${title} ⥤`, css);

  match(level)
    .with("info", () => {
      messages.forEach((msg) => console.log(msg));
    })
    .with("warn", () => {
      messages.forEach((msg) => console.warn(msg));
    })
    .with("error", () => {
      messages.forEach((msg) => console.error(msg));
    })
    .exhaustive();

  console.groupEnd();
};

const openExternalLink = (url: string): IO.IO<void> => {
  return () => {
    return window.open(url, "_blank")?.focus();
  };
};

const reportIssue = (msg: string, producer: "fromElm" | "fromJs"): IO.IO<void> => {
  return () => {
    if (isProd()) {
      Sentry.withScope(function (scope) {
        scope.setTag("producer", producer);
        scope.setContext(producer, { message: msg });

        Sentry.captureMessage(msg);
      });
    }
  };
};

let pubnub: null | PubNub = null;

app.ports.interopFromElm.subscribe((fromElm) => {
  return match(fromElm)
    .with({ tag: "openExternalLink" }, ({ data }) => openExternalLink(data.url)())
    .with({ tag: "reportIssue" }, ({ data }) => reportIssue(data.message, "fromElm")())
    .with({ tag: "subscriptionCreds" }, ({ data }) => {
      if (pubnub !== null) {
        pubnub.stop();
      }

      pubnub = new PubNub({
        subscribeKey: data.subscribeKey,
        userId: data.accountId,
        // logVerbosity: !isProd(),
      });

      pubnub.addListener({
        message: function (m) {
          if (!isProd()) {
            prettyPrint("info", "PubNub Event", [m.message]);
          }

          pipe(
            J.parse(m.message),
            E.match(
              () => {
                prettyPrint("warn", "JSON parse", [m.message]);

                reportIssue("Unable to parse PubNub JSON\n\n".concat(m.message), "fromJs")();
              },
              (json) => {
                app.ports.interopToElm.send(json as any);
              },
            ),
          );
        },
      });

      pubnub.setToken(data.token);

      pubnub.subscribe({
        channels: [`space.${data.spaceId}`],
      });
    })
    .exhaustive();
});

// app.ports.interopFromElm.unsubscribe((_fromElm) => {});
