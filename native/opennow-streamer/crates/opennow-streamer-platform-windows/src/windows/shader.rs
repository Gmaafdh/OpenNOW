use ::windows::Win32::Graphics::Direct3D::{Fxc::D3DCompile, ID3DBlob};
use ::windows::core::PCSTR;
use std::ffi::CStr;

pub(super) fn compile(source: &[u8], entry: &CStr, target: &CStr) -> Result<ID3DBlob, String> {
    let mut code = None;
    let mut errors = None;
    let result = unsafe {
        D3DCompile(
            source.as_ptr().cast(),
            source.len(),
            PCSTR::null(),
            None,
            None,
            PCSTR(entry.as_ptr().cast()),
            PCSTR(target.as_ptr().cast()),
            0,
            0,
            &mut code,
            Some(&mut errors),
        )
    };
    if let Err(error) = result {
        let detail = errors
            .map(|errors| unsafe {
                String::from_utf8_lossy(std::slice::from_raw_parts(
                    errors.GetBufferPointer().cast(),
                    errors.GetBufferSize(),
                ))
                .into_owned()
            })
            .unwrap_or_default();
        return Err(format!("compile native video shader: {error}: {detail}"));
    }
    code.ok_or_else(|| "no native video shader bytecode".to_owned())
}
