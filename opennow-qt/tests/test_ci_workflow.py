from pathlib import Path
import codecs
import hashlib
import os
import re
import zipfile
import subprocess
import sys
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github/workflows"


def jobs(workflow):
    sections = re.split(r"^  ([a-z][a-z-]*):\n", workflow.split("jobs:\n", 1)[1], flags=re.MULTILINE)
    return dict(zip(sections[1::2], sections[2::2]))


class CIWorkflowTest(unittest.TestCase):
    def test_stack_base_branches_run_pr_checks_without_new_push_or_publication_triggers(self):
        ci = (WORKFLOWS / "qt-ci.yml").read_text()
        pull = ci.split("  pull_request:\n", 1)[1].split("  push:\n", 1)[0]
        push = ci.split("  push:\n", 1)[1].split("\nconcurrency:", 1)[0]
        for branch in ("capy/explain-cloud-session-setup", "capy/gfn-correctness/**"):
            self.assertIn(f"      - {branch}\n", pull)
            self.assertNotIn(branch, push)
        self.assertNotIn("pull_request_target:", ci)
        self.assertIn("github.event_name == 'workflow_dispatch'", jobs(ci)["publish-nightly"])

    def test_linux_appimages_deploy_wayland_platform_and_shell_plugins(self):
        for name in ("qt-build.yml", "qt-release-candidate.yml"):
            with self.subTest(workflow=name):
                workflow = (WORKFLOWS / name).read_text()
                self.assertIn("qtwaylandcompositor", workflow)
                self.assertIn("EXTRA_QT_MODULES: waylandcompositor", workflow)
                self.assertIn(
                    "EXTRA_PLATFORM_PLUGINS: libqoffscreen.so;libqwayland-egl.so;libqwayland-generic.so",
                    workflow,
                )
                for plugin in ("platforms/libqwayland-egl.so", "platforms/libqwayland-generic.so",
                               "wayland-shell-integration/libxdg-shell.so"):
                    self.assertIn(f"test -f build/AppDir/usr/plugins/{plugin}", workflow)

    def test_automatic_events_run_checks_without_packages(self):
        ci = (WORKFLOWS / "qt-ci.yml").read_text()
        entries = jobs(ci)
        self.assertEqual(set(entries), {"preflight", "contracts", "checks", "build", "sign-nightly", "publish-nightly"})
        self.assertIn("uses: ./.github/workflows/qt-checks.yml", entries["contracts"])
        self.assertNotIn("    if:", entries["contracts"])
        self.assertIn("    if: github.event_name == 'workflow_dispatch'\n", entries["build"])
        self.assertIn("    needs: [contracts, preflight]\n", entries["build"])
        self.assertIn("uses: ./.github/workflows/qt-build.yml", entries["build"])
        self.assertIn("  pull_request:\n", ci)
        self.assertIn("  push:\n", ci)
        self.assertEqual(ci.count('      - ".github/workflows/qt-checks.yml"'), 2)

    def test_manual_packages_cannot_bypass_dispatch_gate(self):
        entries = jobs((WORKFLOWS / "qt-build.yml").read_text())
        self.assertEqual(set(entries), {"metadata", "packages", "flatpak", "artifact-inventory"})
        self.assertIn("    if: github.event_name == 'workflow_dispatch'\n", entries["metadata"])
        self.assertIn("    needs: metadata\n", entries["packages"])
        self.assertNotIn("always()", entries["packages"])
        self.assertIn("    needs: metadata\n", entries["flatpak"])
        self.assertIn("    needs: [metadata, packages, flatpak]\n", entries["artifact-inventory"])
        self.assertIn("        if: inputs.upload_complete\n", entries["artifact-inventory"])

    def test_all_platforms_share_one_packaging_matrix(self):
        entries = jobs((WORKFLOWS / "qt-build.yml").read_text())
        labels = re.findall(r"^          - label: (.+)$", entries["packages"], re.MULTILINE)
        self.assertCountEqual(labels, ["linux-x64", "linux-arm64", "windows-x64", "windows-arm64", "macos-arm64"])
        self.assertIn("name: Package ${{ matrix.label }}", entries["packages"])
        self.assertIn("Create Linux AppImage", entries["packages"])
        self.assertIn("Test relocated bundle without development libraries", entries["packages"])

    def test_windows_packaging_failure_prints_bounded_logs_and_preserves_status(self):
        workflow = (WORKFLOWS / "qt-build.yml").read_text()
        step = workflow.split("      - name: Create unsigned package\n", 1)[1].split("      - name:", 1)[0]
        script = textwrap.dedent(step.split("        run: |\n", 1)[1])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for index in range(6):
                log = root / f"build/qt-packages/log folder {index}/wix.log"
                log.parent.mkdir(parents=True)
                log.write_text("first-line-must-be-truncated\n" + ("x" * 1024 + "\n") * 300 + "WiX failure detail\n")
            prelude = 'cd() { return 0; }\ncpack() { return "$CPACK_STATUS"; }\n'
            for platform, status in (("Windows", 37), ("Windows", 0), ("Linux", 37)):
                with self.subTest(platform=platform, status=status):
                    result = subprocess.run(["bash", "-euo", "pipefail", "-c", prelude + script],
                                            cwd=root, env={**os.environ, "RUNNER_OS": platform,
                                                           "CPACK_STATUS": str(status), "PACKAGE_GENERATOR": "WIX;ZIP"},
                                            capture_output=True, text=True)
                    self.assertEqual(result.returncode, status, result.stderr)
                    if platform == "Windows" and status:
                        self.assertEqual(result.stdout.count("--- WiX packaging log:"), 4)
                        self.assertEqual(result.stdout.count("WiX failure detail"), 4)
                        self.assertNotIn("first-line-must-be-truncated", result.stdout)
                        self.assertLess(len(result.stdout), 4 * 65536 + 4096)
                    else:
                        self.assertEqual(result.stdout, "")
            result = subprocess.run(["bash", "-euo", "pipefail", "-c",
                                     prelude + 'tail() { return 11; }\n' + script],
                                    cwd=root, env={**os.environ, "RUNNER_OS": "Windows",
                                                   "CPACK_STATUS": "37", "PACKAGE_GENERATOR": "WIX;ZIP"},
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 37, result.stderr)
            for log in root.rglob("wix.log"):
                log.unlink()
            result = subprocess.run(["bash", "-euo", "pipefail", "-c", prelude + script],
                                    cwd=root, env={**os.environ, "RUNNER_OS": "Windows",
                                                   "CPACK_STATUS": "37", "PACKAGE_GENERATOR": "WIX;ZIP"},
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 37, result.stderr)
            self.assertIn("No generated WiX logs found.", result.stdout)

    def test_all_native_platform_checks_keep_required_status_names(self):
        checks = jobs((WORKFLOWS / "qt-ci.yml").read_text())["checks"]
        labels = re.findall(r"^          - label: (.+)$", checks, re.MULTILINE)
        self.assertCountEqual(labels, ["linux-x64", "windows-x64", "macos-arm64"])
        self.assertIn("    name: ${{ matrix.label }}\n", checks)
        self.assertIn("    runs-on: ${{ matrix.os }}\n", checks)
        self.assertIn("      fail-fast: false\n", checks)
        self.assertIn("uses: ./.github/actions/qt-unit-tests", checks)
        self.assertIn("os: blacksmith-16vcpu-windows-2025", checks)
        self.assertIn("os: blacksmith-6vcpu-macos-15", checks)
        self.assertNotIn("continue-on-error", checks)

    def test_linux_and_windows_checks_use_sixteen_core_runners(self):
        checks = jobs((WORKFLOWS / "qt-ci.yml").read_text())["checks"]
        for label, runner in (("linux-x64", "blacksmith-16vcpu-ubuntu-2404"),
                              ("windows-x64", "blacksmith-16vcpu-windows-2025")):
            with self.subTest(label=label):
                entry = checks.split(f"          - label: {label}\n", 1)[1].split("          - label:", 1)[0]
                self.assertIn(f"            os: {runner}\n", entry)
                self.assertIn('            parallel: "8"\n', entry)
        self.assertNotIn("CARGO_BUILD_JOBS:", checks)
        action = (ROOT / ".github/actions/qt-unit-tests/action.yml").read_text()
        self.assertNotIn("CARGO_BUILD_JOBS:", action.split("    - name: Lint Rust", 1)[0])
        for step in ("Lint Rust", "Test Rust"):
            entry = action.split(f"    - name: {step}\n", 1)[1].split("    - name:", 1)[0]
            self.assertIn("CARGO_BUILD_JOBS: ${{ inputs.parallel }}", entry)
        self.assertIn("parallel: ${{ matrix.parallel }}", checks)

    def test_linux_and_windows_packages_use_eight_core_build_parallelism(self):
        packages = jobs((WORKFLOWS / "qt-build.yml").read_text())["packages"]
        for label in ("linux-x64", "linux-arm64", "windows-x64", "windows-arm64"):
            with self.subTest(label=label):
                entry = packages.split(f"          - label: {label}\n", 1)[1].split("          - label:", 1)[0]
                self.assertIn("            os: blacksmith-8vcpu-", entry)
                self.assertIn("            build-parallel: 8\n", entry)

    def test_manual_packages_overlap_checks_without_bypassing_publication_gates(self):
        entries = jobs((WORKFLOWS / "qt-ci.yml").read_text())
        self.assertIn("    needs: [contracts, preflight]\n", entries["build"])
        self.assertIn("    if: github.event_name == 'workflow_dispatch'\n", entries["build"])
        self.assertIn("    needs: [preflight, contracts, checks, build]\n", entries["sign-nightly"])
        self.assertIn("    needs: [contracts, checks, build, sign-nightly]\n", entries["publish-nightly"])
        self.assertNotIn("always()", entries["build"])
        self.assertNotIn("always()", entries["publish-nightly"])
        self.assertNotIn("continue-on-error", entries["checks"])
        self.assertNotIn("continue-on-error", entries["build"])

    def test_required_platform_checks_fail_when_shared_checks_do_not_succeed(self):
        checks = jobs((WORKFLOWS / "qt-ci.yml").read_text())["checks"]
        self.assertIn("    needs: contracts\n    if: ${{ !cancelled() && needs.contracts.result != 'cancelled' }}\n", checks)
        self.assertIn("CONTRACTS_RESULT: ${{ needs.contracts.result }}", checks)
        script = re.search(r"        run: (test .+)\n", checks)[1]
        for result in ("success", "failure", "skipped", ""):
            with self.subTest(result=result):
                process = subprocess.run(["bash", "-c", script], env={**os.environ, "CONTRACTS_RESULT": result})
                self.assertEqual(process.returncode == 0, result == "success")

    def test_checks_compile_tests_without_packaging_or_runtime_targets(self):
        contracts = (WORKFLOWS / "qt-checks.yml").read_text()
        checks = (ROOT / ".github/actions/qt-unit-tests/action.yml").read_text()
        entries = jobs(contracts)
        self.assertEqual(set(entries), {"contracts"})
        self.assertIn("runs-on: blacksmith-2vcpu-ubuntu-2404", entries["contracts"])
        for forbidden in ("matrix:", "cpack ", "linuxdeploy", "upload-artifact", "--release",
                          "uses: ./.github/workflows/qt-build.yml"):
            self.assertNotIn(forbidden, checks)
        self.assertIn('--target opennow-ci-unit-tests --parallel "$BUILD_PARALLEL"', checks)
        self.assertIn("--no-tests=error", checks)
        self.assertIn('-L ci-unit --parallel "$BUILD_PARALLEL" --output-junit qt-unit-tests.xml', checks)
        self.assertIn("Testing/Temporary/LastTest.log", checks)
        self.assertIn("cargo clippy --locked", checks)
        self.assertIn("cargo test --locked", checks)
        self.assertIn("--workspace --all-targets -- -D warnings", checks)
        self.assertIn('"$QT_ROOT_DIR/bin/qmlformat"', checks)
        self.assertNotIn("ensure-windows-test-desktop.ps1", checks)
        self.assertIn("ensure-windows-media-foundation.ps1", checks)
        cmake = (ROOT / "opennow-qt/cmake/Tests.cmake").read_text()
        targets = re.search(r"set\(OPENNOW_CI_UNIT_TEST_TARGETS\s+(.*?)\)", cmake, re.DOTALL)[1].split()
        self.assertEqual(len(targets), 37)
        self.assertEqual(len(set(targets)), 37)
        self.assertIn("opennow-profileimage-tests", targets)
        self.assertIn("opennow-generichidinput-tests", targets)
        self.assertIn("opennow-windowtheme-tests", targets)
        self.assertIn("opennow-updatefailure-tests", targets)
        self.assertIn('add_test(NAME opennow-updatefailure-tests COMMAND opennow-updatefailure-tests', cmake)
        self.assertIn('-input "${CMAKE_CURRENT_SOURCE_DIR}/tests/qml-updater"', cmake)
        self.assertIn("opennow-applicationicons-tests", targets)
        self.assertIn("opennow-streampresenttimings-tests", targets)
        self.assertIn("opennow-fsrupscaler-tests", targets)
        self.assertRegex(cmake, r'if\(WIN32 OR CMAKE_SYSTEM_NAME STREQUAL "Linux"\)\s+'
                         r'set_tests_properties\(opennow-frameinterpolator-tests opennow-fsrupscaler-tests\s+'
                         r'PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen"\)')
        self.assertIn("opennow-tenbitwarning-tests", targets)
        self.assertIn("opennow-consoleactions-tests", targets)
        self.assertIn("opennow-controllernavigation-tests", targets)
        self.assertIn("opennow-graphicsdevices-tests", targets)
        self.assertIn("opennow-consolelayout-tests", targets)
        self.assertIn("opennow-consolecontrols-tests", targets)
        self.assertIn("opennow-consolelaunch-tests", targets)
        self.assertIn("opennow-consolelaunchinput-tests", targets)
        self.assertIn("opennow-macawdl-tests", targets)
        self.assertIn("opennow-controllericons-tests", targets)
        self.assertIn("opennow-streamtoasts-tests", targets)
        self.assertIn("opennow-waylandhdroutput-tests", targets)
        self.assertIn("opennow-queueselector-tests", targets)
        for forbidden in ("opennow-qt", "opennow-streamvideo-tests", "opennow-nativestreamruntime-tests",
                          "opennow-nativeframegeneration-tests", "opennow-linuxvulkangraphics-tests"):
            self.assertNotIn(forbidden, targets)
        self.assertIn("add_custom_target(opennow-ci-unit-tests DEPENDS ${OPENNOW_CI_UNIT_TEST_TARGETS})", cmake)
        self.assertIn('set_tests_properties(${OPENNOW_CI_UNIT_TEST_TARGETS} PROPERTIES LABELS "ci-unit")', cmake)
        self.assertIn('ENVIRONMENT "QT_QPA_PLATFORM=cocoa" RUN_SERIAL TRUE TIMEOUT 30 LABELS "interactive-desktop"', cmake)

    def test_signed_helper_integration_runs_on_every_platform_check_not_signers(self):
        action = (ROOT / ".github/actions/qt-unit-tests/action.yml").read_text()
        marker = "    - name: Test signed update helper integration\n"
        before, after = action.split(marker, 1)
        step = after.split("    - name:", 1)[0]
        for setup in ("uses: ilammy/msvc-dev-cmd@v1", "uses: dtolnay/rust-toolchain@stable",
                      "name: Install Linux test dependencies", "name: Test Rust"):
            self.assertIn(setup, before)
        self.assertNotIn("      if:", step)
        self.assertNotIn("continue-on-error", step)
        self.assertIn("working-directory: ${{ env.OPENNOW_CHECKOUT }}", step)
        self.assertIn("CARGO_BUILD_JOBS: ${{ inputs.parallel }}", step)
        self.assertIn("OPENNOW_UPDATE_TEST_TARGET_DIR: ${{ env.OPENNOW_CHECKOUT }}/native/opennow-core/target", step)
        self.assertIn("python opennow-qt/tests/run_update_helper_integration.py", step)
        self.assertIn("python3 opennow-qt/tests/run_update_helper_integration.py", step)
        self.assertNotIn("secrets.", step)
        ci = jobs((WORKFLOWS / "qt-ci.yml").read_text())
        for label in ("linux-x64", "windows-x64", "macos-arm64"):
            self.assertIn(f"label: {label}", ci["checks"])
        self.assertIn("uses: ./.github/actions/qt-unit-tests", ci["checks"])
        self.assertNotIn("run_update_helper_integration.py", ci["sign-nightly"])
        candidate = jobs((WORKFLOWS / "qt-release-candidate.yml").read_text())
        self.assertNotIn("run_update_helper_integration.py", candidate["inventory"])

    def test_windows_checks_use_verified_llvm_fallback(self):
        action = (ROOT / ".github/actions/qt-unit-tests/action.yml").read_text()
        llvm = (ROOT / ".github/scripts/ensure-windows-llvm.ps1").read_text()
        self.assertIn(".github/scripts/ensure-windows-llvm.ps1", action)
        self.assertNotIn("choco install llvm", action)
        self.assertIn("key: windows-nasm-3.2.0", action)
        self.assertIn("choco install nasm --version=3.2.0 -y --no-progress", action)
        self.assertIn("NASM_CACHE_HIT: ${{ steps.windows-nasm.outputs.cache-hit }}", action)
        self.assertIn("NASM installation failed with exit code", action)
        self.assertIn("Expected NASM 3.02 from Chocolatey package 3.2.0", action)
        self.assertIn("NASM installation is missing nasm.exe", action)
        self.assertIn("LLVM-22.1.8-win64.exe", llvm)
        self.assertIn("16e5709785fef73c854646241c4a92c5cd574318d1b33c63330dd7721903e55c", llvm)
        self.assertIn("LLVM-22.1.8-woa64.exe", llvm)
        self.assertIn("76f44ef1ba6eeb5a65904e9500f042f588fade49952778ce48f0374daa934396", llvm)
        self.assertIn("Get-FileHash -Algorithm SHA256", llvm)
        self.assertIn("libclang.dll", llvm)
        self.assertIn("LIBCLANG_PATH=$llvmBin", llvm)
        self.assertIn("Unsupported Windows LLVM runner architecture", llvm)

    def test_interactive_tests_remain_registered_outside_headless_ci(self):
        cmake = (ROOT / "opennow-qt/cmake/Tests.cmake").read_text()
        self.assertIn("list(REMOVE_ITEM OPENNOW_CI_UNIT_TEST_TARGETS opennow-hdrcolor-tests)", cmake)
        self.assertIn('set_tests_properties(opennow-hdrcolor-tests PROPERTIES LABELS "interactive-desktop")', cmake)
        self.assertIn("add_custom_target(opennow-interactive-tests DEPENDS opennow-hdrcolor-tests)", cmake)
        self.assertIn("add_custom_target(opennow-interactive-tests DEPENDS opennow-macpointer-tests)", cmake)
        self.assertIn("add_test(NAME opennow-hdrcolor-tests", cmake)
        self.assertIn("add_test(NAME opennow-macpointer-native-tests", cmake)
        runtime_consumers = cmake.split("foreach(test_target IN ITEMS", 1)[1]
        self.assertIn("opennow-hdrcolor-tests", runtime_consumers)
        packages = (WORKFLOWS / "qt-build.yml").read_text()
        self.assertEqual(packages.count("--no-tests=error -LE interactive-desktop"), 2)

    def test_general_purpose_runners_are_blacksmith(self):
        for workflow in WORKFLOWS.glob("*.yml"):
            # The branch-only unsigned executable harness has its own strict
            # hosted-runner contract below; production runner policy is unchanged.
            if workflow.name == "arena-windows-exe.yml":
                continue
            runners = re.findall(r"^\s+(?:runs-on|os|runner): (.+)$", workflow.read_text(), re.MULTILINE)
            for runner in runners:
                with self.subTest(workflow=workflow.name, runner=runner):
                    self.assertTrue(
                        runner.startswith(("blacksmith-", "${{")),
                    )

    def test_hosted_windows_executable_is_branch_scoped_and_unsigned(self):
        workflow = (WORKFLOWS / "arena-windows-exe.yml").read_text()
        self.assertEqual(
            re.findall(r"^\s+runs-on: (.+)$", workflow, re.MULTILINE),
            ["ubuntu-24.04", "windows-2025", "ubuntu-24.04", "ubuntu-24.04", "ubuntu-24.04"],
        )
        self.assertIn("    needs: contracts", workflow)
        self.assertEqual(workflow.count("    if: github.ref == 'refs/heads/arena/15b83ddf-opennow'"), 2)
        self.assertIn("    branches:\n      - arena/15b83ddf-opennow\n", workflow)
        self.assertIn("    if: github.ref == 'refs/heads/arena/15b83ddf-opennow'", workflow)
        # Session branches build through the same harness, so each one has to be
        # listed for the push trigger *and* for every job gate that should run on
        # it; a branch that only matches the trigger would silently skip them.
        self.assertIn("      - arena/c8d904a5-opennow\n", workflow)
        self.assertEqual(workflow.count("github.ref == 'refs/heads/arena/c8d904a5-opennow'"), 2)
        # The branch that publishes the archived 146.1 release runs the contracts
        # job, the staging job and the publish job only. It must never reach the
        # Windows build gate: that would spend 35 minutes rebuilding the very
        # package these jobs exist to restore without building.
        self.assertIn("      - arena/2a2749e0-opennow\n", workflow)
        self.assertEqual(workflow.count("github.ref == 'refs/heads/arena/2a2749e0-opennow'"), 3)
        self.assertIn("  contents: read", workflow)
        for prohibited in ("pull_request:", "pull_request_target:", "secrets.", "environment:"):
            with self.subTest(prohibited=prohibited):
                self.assertNotIn(prohibited, workflow)
        # The harness publishes two things and nothing else: the rolling
        # arena-fast pre-release that the in-app update button installs from, and
        # the fixed 1.0.3-nightly.146.1 full release restored from its archived
        # artifact. Only the Windows build job, the restore job and the 146.1
        # publish job may write contents.
        self.assertEqual(workflow.count("      contents: write"), 3)
        self.assertIn("    permissions:\n      contents: write\n", workflow)
        for release_command in re.findall(r"gh release \w+ (\S+)", workflow):
            with self.subTest(release=release_command):
                self.assertIn(release_command, {"arena-fast", "1.0.3-nightly.146.1"})
        self.assertIn("gh release upload arena-fast $zip $manifest", workflow)
        self.assertIn("run-id: 42347482232", workflow)
        self.assertIn("actions/download-artifact@v4", workflow)
        self.assertIn("Restore existing Windows nightly 146.1 (no rebuild)", workflow)
        self.assertIn("if: github.run_number <= 146", workflow)
        self.assertIn("No build was run.", workflow)
        self.assertNotIn("--latest", workflow)
        self.assertIn("--prerelease", workflow)
        self.assertIn("-p opennow-streamer-platform-windows -p opennow-streamer-protocol", workflow)
        self.assertIn("--lib -- --test-threads=1 --nocapture", workflow)
        self.assertIn("--target opennow-qt opennow-graphicsdevices-tests", workflow)
        self.assertIn("opennow-profileimage-tests opennow-queueselector-tests", workflow)
        self.assertIn("opennow-queueselector-tests.exe", workflow)
        self.assertIn("-o ci-logs/queueselector-tests.log,txt", workflow)
        self.assertIn("ci-logs/queue-selector-acceptance.log", workflow)
        self.assertIn("QT_FORCE_STDERR_LOGGING=1", workflow)
        self.assertIn('QT_QPA_FONTDIR="$(cygpath -w "$PWD/opennow-qt/res/fonts")"', workflow)
        acceptance = workflow.split("      - name: Exercise queue transition and capture the redesigned page\n", 1)[1]
        acceptance = acceptance.split("      - name: Package portable ZIP\n", 1)[0]
        self.assertIn("--smoke-queue-selector", acceptance)
        self.assertIn("ci-logs/queue-selector.png", acceptance)
        self.assertIn("--config Release --parallel 4", workflow)
        self.assertIn("Assert-OpenNowPackagePayload", workflow)
        self.assertIn("packaging/windows/build-setup.ps1", workflow)
        self.assertIn("name: OpenNOW-Windows-x64-dx10", workflow)
        self.assertIn("retention-days: 14", workflow)

    def test_archived_146_1_is_published_as_a_full_release_with_both_packages(self):
        workflow = (WORKFLOWS / "arena-windows-exe.yml").read_text()
        self.assertIn("  publish-windows-146-release:\n", workflow)
        job = workflow.split("  publish-windows-146-release:", 1)[1]
        self.assertIn("Publish Windows nightly 146.1 as a full release", job)
        # Reading an artifact out of another workflow run is what needs
        # actions: read, and asking for it alongside contents: write is what
        # GitHub answered with "Resource not accessible by integration" when the job
        # tried to create the release. The download therefore lives in its own
        # job, and the publishing token asks for the single scope that this
        # workflow already publishes arena-fast with.
        staged = workflow.split("  stage-windows-146-packages:", 1)[1].split("\n  publish-windows-146-release:", 1)[0]
        self.assertIn("Stage the archived 146.1 packages for publication", staged)
        self.assertIn("run-id: 42347482232", staged)
        self.assertIn("      actions: read\n", staged)
        self.assertNotIn("contents: write", staged)
        self.assertIn("name: windows-146-packages", staged)
        self.assertIn("      - stage-windows-146-packages\n", job)
        self.assertIn("      contents: write\n", job)
        self.assertNotIn("actions: read", job)
        self.assertIn("name: windows-146-packages\n", job)
        # A permission refusal has to name itself rather than leave a bare 403.
        self.assertIn('"Publishing token access"', job)
        # Opt-in by commit message, like the restore job, so an ordinary push to
        # this branch cannot republish a release by accident.
        self.assertIn("contains(github.event.head_commit.message, '[publish-windows-146.1]')", job)
        # The tag points at the commit the archived build actually came from.
        self.assertIn("local commit=b3d3c72948bc3732532041cb33edafb7b7497889", job)
        self.assertIn('-f "target_commitish=$commit"', job)
        # Both packages ship: the installer next to the portable archive.
        self.assertIn("OpenNOW-Qt-1.0.3-nightly.146.1-Windows-x64-setup.exe", job)
        self.assertIn("OpenNOW-Qt-1.0.3-nightly.146.1-Windows-x64.zip", job)
        self.assertIn("SHA256SUMS does not cover both the installer and the portable archive", job)
        # A refusal has to be readable without the job log, which lives on a
        # blob host that is not reachable from every network: each outcome is
        # annotated, and a failed publish also carries its gh conversation out.
        for title in (
            "146.1 publish verification failed",
            "146.1 release creation failed",
            "146.1 asset upload failed",
        ):
            self.assertIn(title, job)
        self.assertIn("if: failure()", job)
        self.assertIn("ci-logs/publish-release.log", job)
        # Created through the REST API as a release: not a draft, not a
        # pre-release, and GitHub is left to mark it latest on its own terms.
        self.assertIn("-F draft=false", job)
        self.assertIn("-F prerelease=false", job)
        # make_latest is a string in the REST API, unlike those two booleans.
        self.assertIn("-f make_latest=true", job)
        # "gh api --jq" writes the JSON error body to stdout when the tag has no
        # release yet, so a probe that only tests whether its output is non-empty
        # concludes the release already exists and then dies on the first
        # follow-up query under set -e. Existence goes by exit status and the id
        # is accepted only when it is all digits.
        self.assertIn('if gh release view 1.0.3-nightly.146.1 --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then', job)
        self.assertIn("case $release_id in ''|*[!0-9]*) release_id=\"\" ;; esac", job)
        # Assets go up through the same proven call the fast channel uses, so a
        # re-run completes a half-published release instead of failing on it.
        self.assertIn("gh release upload 1.0.3-nightly.146.1", job)
        self.assertIn("--clobber", job)
        # Both metadata files come off a Windows runner, so CRLF and the byte
        # order mark have to be normalised before anything is compared.
        self.assertIn('encoding="utf-8-sig"', job)
        self.assertIn('replace("\\r\\n", "\\n")', job)
        # A release, not a pre-release, and never marked latest by hand.
        self.assertNotIn("--prerelease", job)
        self.assertNotIn("--latest", job)
        # It refuses to move a tag that points somewhere else, and re-running it
        # completes a half-published release instead of clobbering a good one.
        self.assertIn("refusing to overwrite it", job)
        self.assertIn("already exists with all ${#assets[@]} assets; nothing to publish", job)
        # Same verification chain the restore job uses, extended to both packages.
        for proof in (
            "Version: {version}",
            "Source commit: {source_commit}",
            "Checksum verification failed for",
            "/bin/OpenNOW.exe",
        ):
            self.assertIn(proof, job)

    def test_publish_verifier_accepts_the_windows_package_metadata_it_will_meet(self):
        # The verifier runs against files a Windows runner wrote with Set-Content:
        # CRLF endings and a byte order mark. A version that compared them as-is
        # kept a trailing CR on every SHA256SUMS filename, matched nothing, and
        # failed the publish job with a bare exit code, so the script embedded in
        # the workflow is extracted and run here against that exact fixture.
        workflow = (WORKFLOWS / "arena-windows-exe.yml").read_text()
        job = workflow.split("  publish-windows-146-release:", 1)[1]
        # The heredoc terminator is indented in the raw YAML, so slice on the
        # bare word and let dedent remove the block indentation afterwards.
        script = textwrap.dedent(re.split(r"\n[ \t]*PYTHON\n", job.split("<<'PYTHON'\n", 1)[1], 1)[0])
        version = "1.0.3-nightly.146.1"
        commit = "b3d3c72948bc3732532041cb33edafb7b7497889"
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            payload = root / "payload" / "bin"
            payload.mkdir(parents=True)
            (payload / "OpenNOW.exe").write_bytes(b"MZ fake executable")
            archive = root / f"OpenNOW-Qt-{version}-Windows-x64.zip"
            with zipfile.ZipFile(archive, "w") as opened:
                opened.write(payload / "OpenNOW.exe", "bin/OpenNOW.exe")
            installer = root / f"OpenNOW-Qt-{version}-Windows-x64-setup.exe"
            installer.write_bytes(b"fake installer payload")
            info = "\r\n".join([
                "OpenNOW Windows x64 unsigned compatibility test build",
                f"Version: {version}",
                f"Source commit: {commit}",
                "Run: https://github.com/Gmaafdh/OpenNOW/actions/runs/42347482232",
            ]) + "\r\n"
            (root / "BUILD-INFO.txt").write_bytes(codecs.BOM_UTF8 + info.encode("utf-8"))
            sums = "".join(
                f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\r\n"
                for path in (archive, installer)
            )
            (root / "SHA256SUMS").write_bytes(sums.encode("ascii"))

            result = subprocess.run(
                [sys.executable, "-c", script, str(root)], capture_output=True, text=True
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("146.1 packages verified", result.stdout)
            manifest = archive.with_name(archive.name + ".manifest.json")
            self.assertTrue(manifest.is_file())
            notes = root / "RELEASE-NOTES.md"
            self.assertTrue(notes.is_file())
            for package in (archive, installer):
                self.assertIn(package.name, notes.read_text())

            # The same fixture with one corrupted byte must refuse to publish and
            # must say so in an annotation rather than only in the job log.
            installer.write_bytes(b"X" + installer.read_bytes()[1:])
            broken = subprocess.run(
                [sys.executable, "-c", script, str(root)], capture_output=True, text=True
            )
            self.assertEqual(broken.returncode, 1)
            self.assertIn("146.1 publish verification failed", broken.stdout)
            self.assertIn("Checksum verification failed for", broken.stdout)

    def test_windows_ctest_annotation_preserves_the_first_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "ctest.log"
            log.write_text(
                "8: FAIL!  : QueueSelector::test_scaledLayout(compact-large) "
                "Launch action exceeds the dialog\n"
                + ("3: later passing test output\n" * 240)
                + "The following tests FAILED:\n\t8 - opennow-queueselector-tests (Failed)\n"
            )
            result = subprocess.run(
                [sys.executable, str(ROOT / ".github/scripts/report-build-log-failures.py"), directory],
                capture_output=True, text=True, check=True,
            )
            self.assertIn("Launch action exceeds the dialog", result.stdout)
            self.assertIn("The following tests FAILED", result.stdout)

    def test_rust_caches_survive_job_renames_and_later_test_failures(self):
        for path in (ROOT / ".github/actions/qt-unit-tests/action.yml", WORKFLOWS / "qt-build.yml"):
            with self.subTest(path=path):
                cache = path.read_text().split("uses: Swatinem/rust-cache@", 1)[1].split("\n      -", 1)[0]
                self.assertIn("shared-key:", cache)
                self.assertIn("cache-on-failure: true", cache)
                self.assertIn("native/opennow-core -> target", cache)
                self.assertIn("native/opennow-streamer -> target", cache)

    def test_qt_compile_cache_restores_previous_timestamped_entries(self):
        action = (ROOT / ".github/actions/qt-unit-tests/action.yml").read_text()
        cache = action.split("uses: hendrikmuhs/ccache-action@", 1)[1].split("\n    - name:", 1)[0]
        self.assertIn("key: qt-checks-${{ inputs.label }}", cache)
        self.assertIn("restore-keys: qt-checks-${{ inputs.label }}", cache)
        self.assertIn("verbose: 1", cache)
        cmake = (ROOT / "opennow-qt/CMakeLists.txt").read_text()
        self.assertIn("cmake_policy(SET CMP0141 NEW)", cmake)
        self.assertIn('set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "$<$<CONFIG:Debug,RelWithDebInfo>:Embedded>")', cmake)
        tests = (ROOT / "opennow-qt/cmake/Tests.cmake").read_text()
        self.assertIn("set_property(TARGET opennow-hdrcolor-tests PROPERTY MSVC_DEBUG_INFORMATION_FORMAT Embedded)", tests)
        self.assertIn("target_compile_options(opennow-hdrcolor-tests PRIVATE /Zi)", tests)

    def test_package_compile_caches_restore_their_own_timestamped_entries(self):
        for workflow_name, job_names in (
            ("qt-build.yml", ("packages",)),
            ("qt-release-candidate.yml", ("linux", "windows", "macos")),
        ):
            workflow_jobs = jobs((WORKFLOWS / workflow_name).read_text())
            for job_name in job_names:
                with self.subTest(workflow=workflow_name, job=job_name):
                    cache = workflow_jobs[job_name].split("uses: hendrikmuhs/ccache-action@", 1)[1].split("\n      -", 1)[0]
                    key = re.search(r"^\s+key: (.+)$", cache, re.MULTILINE).group(1)
                    self.assertIn(f"restore-keys: {key}\n", cache)
                    self.assertIn("verbose: 1", cache)
                    self.assertNotIn("append-timestamp: false", cache)

    def test_release_candidates_reuse_the_nightly_package_caches(self):
        def block(job, action):
            return job.split(f"uses: {action}@", 1)[1].split("\n      -", 1)[0]

        def key_expression(cache, name):
            return re.search(rf"^\s+{name}: (.+)$", cache, re.MULTILINE).group(1)

        nightly = jobs((WORKFLOWS / "qt-build.yml").read_text())["packages"]
        candidates = jobs((WORKFLOWS / "qt-release-candidate.yml").read_text())

        # Resolve the nightly package job's own key expression per matrix entry,
        # so a rename in either workflow has to move both sides together.
        nightly_rust = block(nightly, "Swatinem/rust-cache")
        self.assertEqual(key_expression(nightly_rust, "shared-key"),
                         key_expression(block(nightly, "hendrikmuhs/ccache-action"), "key"))
        expression = key_expression(nightly_rust, "shared-key")
        macos = re.search(r"runner\.os == 'macOS' && '(qt-ci-[^']+)'", expression)
        template = re.search(r"format\('(\S+)', matrix\.os, matrix\.label\)", expression)
        self.assertIsNotNone(macos, expression)
        self.assertIsNotNone(template, expression)
        platforms = {
            label: macos[1] if "macos" in image
            else template[1].replace("{0}", image).replace("{1}", label)
            for label, image in re.findall(r"- label: (\S+)\n\s+os: (\S+)\n", nightly)
        }
        self.assertEqual(set(platforms), {
            "linux-x64", "linux-arm64", "windows-x64", "windows-arm64", "macos-arm64",
        })
        # A candidate restores the nightly cache only when its own key pattern
        # resolves to that platform's key.
        linux = key_expression(block(candidates["linux"], "Swatinem/rust-cache"), "shared-key")
        windows = key_expression(block(candidates["windows"], "Swatinem/rust-cache"), "shared-key")
        self.assertEqual({
            **{
                f"linux-{arch}": linux.replace("${{ matrix.runner }}", runner)
                                      .replace("${{ matrix.arch }}", arch)
                for arch, runner in re.findall(r"- arch: (\S+)\n\s+runner: (\S+)\n", candidates["linux"])
            },
            **{
                f"windows-{arch}": windows.replace("${{ matrix.arch }}", arch)
                for arch in re.findall(r"- arch: (\S+)\n", candidates["windows"])
            },
            "macos-arm64": key_expression(block(candidates["macos"], "Swatinem/rust-cache"), "shared-key"),
        }, platforms)

        nightly_workspaces = nightly_rust.split("workspaces: |", 1)[1].strip()
        self.assertIn("native/opennow-core -> ../../build/opennow-qt-release/rust-target", nightly_workspaces)
        for name in ("linux", "windows", "macos"):
            with self.subTest(candidate=name):
                rust = block(candidates[name], "Swatinem/rust-cache")
                ccache = block(candidates[name], "hendrikmuhs/ccache-action")
                self.assertEqual(key_expression(rust, "shared-key"), key_expression(ccache, "key"))
                self.assertEqual(rust.split("workspaces: |", 1)[1].strip(), nightly_workspaces)
                self.assertEqual(key_expression(ccache, "restore-keys"), key_expression(ccache, "key"))
                self.assertIn("max-size: 1G", ccache)

        self.assertEqual(re.search(r"cache-key-prefix: (qt-target-.+)$", nightly, re.MULTILINE).group(1),
                         "qt-target-${{ matrix.label }}")
        for name, prefix in (("linux", "qt-target-linux-${{ matrix.arch }}"),
                             ("windows", "qt-target-windows-${{ matrix.arch }}"),
                             ("macos", "qt-target-macos-arm64")):
            with self.subTest(candidate=name):
                self.assertIn(f"cache-key-prefix: {prefix}\n", candidates[name])

    def test_relocated_core_probe_matches_shell_protocol(self):
        header = (ROOT / "opennow-qt/src/core/CoreClient.h").read_text()
        version = int(re.search(r"CurrentProtocolVersion = (\d+);", header).group(1))
        core = (ROOT / "native/opennow-core/src/main.rs").read_text()
        self.assertEqual(int(re.search(r"const PROTOCOL_VERSION: i64 = (\d+);", core).group(1)), version)
        for name in ("qt-build.yml", "qt-release-candidate.yml"):
            with self.subTest(workflow=name):
                workflow = (WORKFLOWS / name).read_text()
                probe = workflow.split('"id":"package-core"', 1)[1].split("core.stdin.flush()", 1)[0]
                self.assertEqual(int(re.search(r'"protocolVersion":(\d+)', probe).group(1)), version)

    def test_publishing_remains_explicitly_opt_in_after_build(self):
        ci = (WORKFLOWS / "qt-ci.yml").read_text()
        self.assertIn("        type: boolean\n        default: false", ci)
        publish = jobs(ci)["publish-nightly"]
        self.assertIn("if: github.event_name == 'workflow_dispatch' && inputs.publish_nightly", publish)
        self.assertIn("    needs: [contracts, checks, build, sign-nightly]\n", publish)


if __name__ == "__main__":
    unittest.main()
