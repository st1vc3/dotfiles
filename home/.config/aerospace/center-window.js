ObjC.import("AppKit");

function run(arguments) {
  const processName = arguments[0];
  const systemEvents = Application("System Events");
  const process = systemEvents.processes.byName(processName);

  for (let attempt = 0; attempt < 20; attempt += 1) {
    if (process.exists() && process.windows.length > 0) {
      const window = process.windows[0];
      const [windowWidth, windowHeight] = window.size();
      const [windowX, windowY] = window.position();
      const primaryTop = Number($.NSScreen.mainScreen.frame.size.height);
      const windowCenterX = windowX + windowWidth / 2;
      const windowCenterY = primaryTop - (windowY + windowHeight / 2);
      const screens = $.NSScreen.screens.js;
      const screen = screens.find((candidate) => {
        const frame = candidate.frame;
        const left = Number(frame.origin.x);
        const bottom = Number(frame.origin.y);
        return windowCenterX >= left
          && windowCenterX < left + Number(frame.size.width)
          && windowCenterY >= bottom
          && windowCenterY < bottom + Number(frame.size.height);
      }) || $.NSScreen.mainScreen;
      const visibleFrame = screen.visibleFrame;
      const visibleLeft = Number(visibleFrame.origin.x);
      const visibleTop = primaryTop
        - Number(visibleFrame.origin.y)
        - Number(visibleFrame.size.height);
      window.position = [
        Math.round(visibleLeft + (Number(visibleFrame.size.width) - windowWidth) / 2),
        Math.round(visibleTop + (Number(visibleFrame.size.height) - windowHeight) / 2),
      ];
    }
    delay(0.1);
  }
}
