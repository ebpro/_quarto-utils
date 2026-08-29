const artifact = require('@actions/artifact');
const glob = require('glob');
const path = require('path');

(async () => {
  try {
    const client = artifact.create();
    const outputPath = process.env.OUTPUT_PATH || '_output';
    const repo = process.env.GITHUB_REPOSITORY ? process.env.GITHUB_REPOSITORY.split('/').pop() : 'repo';
    const short = process.env.GITHUB_SHA ? process.env.GITHUB_SHA.substring(0,7) : 'local';

    const patterns = [path.join(outputPath, '**', '*.pdf'), path.join(outputPath, '**', '*.html'), path.join(outputPath, '**', '*.zip')];
    for (const pattern of patterns) {
      const files = glob.sync(pattern, { nodir: true });
      for (const f of files) {
        const base = path.basename(f);
        // Determine profile: for zip files, we can infer from filename if it contains the profile
        let profile = 'notes';
        const lower = f.toLowerCase();
        if (lower.includes('/_slides/') || lower.includes('/_slide/') || lower.includes('/slides/') || base.toLowerCase().includes('-slides-')) {
          profile = 'slides';
        } else if (base.toLowerCase().includes('-notes-') || lower.includes('/_notes/') ) {
          profile = 'notes';
        }
        const artifactName = `${repo}-${short}-${profile}-${base}`;
        console.log(`Uploading ${f} as ${artifactName}`);
        try {
          await client.uploadArtifact(artifactName, [f], path.dirname(f));
        } catch (err) {
          console.error('Upload failed for', f, err);
        }
      }
    }
  } catch (err) {
    console.error('Uploader failed', err);
    process.exit(2);
  }
})();
