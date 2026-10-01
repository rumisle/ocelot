import asyncio, json, sys
from playwright.async_api import async_playwright

URL = "http://127.0.0.1:4852"
ENGINE = sys.argv[1] if len(sys.argv) > 1 else "webkit"
MODE = sys.argv[2] if len(sys.argv) > 2 else "wheel"

# Every animation frame: which turn is at the top of the viewport and where it sits.
SAMPLER = """() => {
  window.__frames = []
  const scroller = () => [...document.querySelectorAll('*')].find(e => e.scrollHeight > e.clientHeight + 50 && /auto|scroll/.test(getComputedStyle(e).overflowY) && e.clientHeight > 300)
  const tick = () => {
    const users = [...document.querySelectorAll('[data-component="user-message"]')]
    let top
    for (const e of users) {
      const r = e.getBoundingClientRect()
      if (r.bottom > 0 && r.top < innerHeight) { top = [+(e.innerText.match(/turn (\\d+)/)?.[1] ?? 0), Math.round(r.top)]; break }
    }
    const s = scroller()
    window.__frames.push([Math.round(performance.now()), top?.[0] ?? null, top?.[1] ?? null, s ? Math.round(s.scrollTop) : null, s ? s.scrollHeight : null])
    if (window.__sampling) requestAnimationFrame(tick)
  }
  window.__sampling = true
  requestAnimationFrame(tick)
}"""


async def main():
    async with async_playwright() as pw:
        browser = await getattr(pw, ENGINE).launch()
        device = pw.devices["iPhone 15"] if ENGINE == "webkit" else {"viewport": {"width": 390, "height": 844}, "has_touch": True, "is_mobile": True}
        context = await browser.new_context(**device, record_video_dir="/out/video", record_video_size={"width": 390, "height": 664})
        page = await context.new_page()
        await page.goto(URL + "/", wait_until="domcontentloaded")
        await page.wait_for_timeout(2500)
        await page.locator("input[type=password]").fill("test")
        await page.get_by_role("button", name="Connect").click()
        await page.wait_for_timeout(2500)
        await page.get_by_text("scrollback", exact=True).first.click()
        await page.wait_for_timeout(4000)
        await page.evaluate(SAMPLER)
        # Scroll up the way a thumb does: steady strokes, without waiting for pages to load.
        for _ in range(140):
            await page.evaluate("""() => { const s = [...document.querySelectorAll('*')].find(e => e.scrollHeight > e.clientHeight + 50 && /auto|scroll/.test(getComputedStyle(e).overflowY) && e.clientHeight > 300); const target = s.querySelector('[data-timeline-key]') ?? s; const touch = (type, y) => { const t = new Touch({ identifier: 1, target, clientX: 195, clientY: y }); target.dispatchEvent(new TouchEvent(type, { touches: type === 'touchend' ? [] : [t], changedTouches: [t], bubbles: true })) }; if (TOUCH) { touch('touchstart', 300); touch('touchmove', 700) } else s.dispatchEvent(new WheelEvent('wheel', { deltaY: -400, bubbles: true })); s.scrollBy(0, -400); if (TOUCH) touch('touchend', 700) }""".replace("TOUCH", "true" if MODE == "touch" else "false"))
            await page.wait_for_timeout(60)
        await page.wait_for_timeout(1500)
        await page.evaluate("() => { window.__sampling = false }")
        frames = await page.evaluate("() => window.__frames")
        await context.close()
        await browser.close()
    json.dump(frames, open(f"/out/frames-{ENGINE}-{MODE}.json", "w"))
    # While scrolling up, the top turn should only go down. A higher turn at the top, or the same
    # turn jumping far down the screen within one frame, is the content shifting under the user.
    backward = []
    shifts = []
    for previous, current in zip(frames, frames[1:]):
        if previous[1] is None or current[1] is None:
            continue
        if current[1] > previous[1]:
            backward.append((current[0], previous[1], current[1], previous[4], current[4]))
        if current[1] == previous[1] and abs(current[2] - previous[2]) > 300:
            shifts.append((current[0], current[1], previous[2], current[2], previous[4], current[4]))
    path = [frames[0][1]] + [f[1] for a, f in zip(frames, frames[1:]) if f[1] != a[1]]
    print(json.dumps({"engine": ENGINE, "mode": MODE, "frames": len(frames), "top-turn path": path, "backward": backward[:15], "big shifts in one frame": shifts[:15]}))


asyncio.run(main())
