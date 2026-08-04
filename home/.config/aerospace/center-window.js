ObjC.import("AppKit");

function run(arguments) {
  const processSelector = arguments[0];
  const systemEvents = Application("System Events");
  const process = /^\d+$/.test(processSelector)
    ? systemEvents.processes.whose({ unixId: Number(processSelector) })[0]
    : systemEvents.processes.byName(processSelector);

  for (let attempt = 0; attempt < 20; attempt += 1) {
    if (process.exists() && process.windows.length > 0) {
      const window = process.windows[0];
      const [windowWidth, windowHeight] = window.size();
      const frame = $.NSScreen.mainScreen.visibleFrame;
      const screenWidth = Number(frame.size.width);
      const screenHeight = Number(frame.size.height);
      window.position = [
        Math.round((screenWidth - windowWidth) / 2),
        Math.round((screenHeight - windowHeight) / 2),
      ];
      return;
    }
    delay(0.1);
  }
}
